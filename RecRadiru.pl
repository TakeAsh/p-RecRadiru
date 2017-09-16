#!/usr/bin/perl
# Record NHK Net Radio らじる★らじる
# usage: RecRadiru.pl <area> <channel> <duration> [<title>] [<outdir>]

use strict;
use warnings;
use utf8;
use Encode;
use FindBin;
use YAML::Syck qw(Load LoadFile Dump DumpFile);
use LWP::UserAgent;
use URI;
use XML::Simple qw(:strict);
use Time::Piece;

$YAML::Syck::ImplicitUnicode   = 1;
$XML::Simple::PREFERRED_PARSER = 'XML::Parser';

my $charset = 'utf-8';    # utf-8, CP932

binmode( STDIN,  ":encoding($charset)" );
binmode( STDOUT, ":encoding($charset)" );
binmode( STDERR, ":encoding($charset)" );

my @channels = qw( r1 r2 fm );

my $path       = $FindBin::RealBin . '/';
my $configYaml = $path . 'config.yml';
my $config     = LoadFile($configYaml) or die("$configYaml: $!");
my $hostYaml   = $path . 'config_Host.yml';
my $host       = LoadFile($hostYaml) or die("$hostYaml: $!");

# YAML ファイルの整形
if (0) {
    foreach my $f ( glob("config*") ) {
        print "$f\n";
        DumpFile( $path . $f, LoadFile( $path . $f ) );
    }
    exit;
}

my $ua       = LWP::UserAgent->new;
my $response = $ua->get( $config->{'RadiruConfig'} );
if ( !$response->is_success ) {
    die( $response->status_line . "\n" );
}
my $radiruConfig = XMLin(
    $response->decoded_content,
    ForceArray => ['data'],
    GroupTags  => { 'stream_url' => 'data' },
    KeyAttr    => { 'data' => '+area' },
);
my $streamUrl = $radiruConfig->{'stream_url'};

my @areas = keys( %{$streamUrl} );
my %apikeyToArea = map { $streamUrl->{$_}{'apikey'} => $_ } @areas;
my $helpMessage
    = "usage: $0 <area> <channel> <duration> [<title>] [<outdir>]\narea: "
    . join( " | ", map { $apikeyToArea{$_} } sort( keys(%apikeyToArea) ) )
    . "\nchannel: "
    . join( " | ", @channels )
    . "\nduration: minuites\n";

if ( @ARGV < 3 ) {
    die($helpMessage);
}
my @argv     = map { decode( $charset, $_ ) } @ARGV;
my $area     = $argv[0];
my $channel  = $argv[1];
my $duration = $argv[2];
my $title    = $argv[3] || "${area}_${channel}";
my $outdir   = $argv[4] || $host->{'SavePath'} || $ENV{'HOME'} || ".";
if ( $duration <= 0 || !grep( /^$area$/, @areas ) || !grep( /^$channel$/, @channels ) ) {
    die($helpMessage);
}
my $endTime = $duration * 60 + time();
while ( ( my $restDuration = $endTime - time() ) > 0 ) {
    my $t       = localtime;
    my $postfix = $t->ymd('') . '_' . $t->hms('');
    my $outfile = "${outdir}/${title}_${postfix}.m4a";

    # 番組情報ダウンロード
    my $infoUrl    = URI->new( $config->{'RadiruInfo'}{'Uri'} );
    my $infoParams = $config->{'RadiruInfo'}{'Params'};
    $infoParams->{'area'} = $streamUrl->{$area}{'apikey'};
    $infoUrl->query_form($infoParams);
    my $infofile = "${outdir}/${title}_${postfix}." . $infoParams->{'mode'};
    $ua->request( HTTP::Request->new( GET => $infoUrl ), $infofile );

    # m4a ダウンロード
    my $ffmpegCmd = sprintf(
        '"%s" -y -i "%s" -bsf:a aac_adtstoasc -c copy -t %d "%s"',
        $host->{'FfmpegPath'},
        $streamUrl->{$area}{ $channel . 'hls' },
        $restDuration + $config->{'ExtendSeconds'}, $outfile
    );
    system( encode( $charset, $ffmpegCmd ) );

    # mp4 タグ埋め込み
    if ( $host->{'Mp4tagsPath'} ) {
        my $mp4tagsCmd = sprintf(
            '"%s" -song "%s" -genre "radio" -year %d %s',
            $host->{'Mp4tagsPath'},
            $title, $t->year, $outfile
        );
        system( encode( $charset, $mp4tagsCmd ) );
    }

    # ダウンロード時間が再生時間より短いので終了時刻前にDL完了する。
    # 開始時10秒分, 終了時10秒分待機する。
    sleep( 10 + 10 );
}

# EOF
