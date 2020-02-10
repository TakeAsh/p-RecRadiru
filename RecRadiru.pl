#!/usr/bin/perl
# Record NHK Net Radio らじる★らじる
# usage: RecRadiru.pl <area> <channel> <duration> [<title>] [<outdir>]

use strict;
use warnings;
use utf8;
use feature qw(say);
use Encode;
use FindBin::libs;
use YAML::Syck qw(Load LoadFile Dump DumpFile);
use JSON::XS;
use LWP::UserAgent;
use URI;
use XML::Simple qw(:strict);
use Time::Piece;
use Try::Tiny;
use IPC::Cmd qw(can_run run QUOTE);
use Term::Encoding qw(term_encoding);
use open ':std' => ( $^O eq 'MSWin32' ? ':locale' : ':utf8' );

$YAML::Syck::ImplicitUnicode   = 1;
$XML::Simple::PREFERRED_PARSER = 'XML::Parser';

my $charset = $^O eq 'MSWin32' ? 'CP932' : 'UTF-8';

my $json     = JSON::XS->new->utf8(0)->allow_nonref(1);
my @channels = qw( r1 r2 fm );

my $configYaml = "${FindBin::RealBin}/config.yml";
my $config     = LoadFile($configYaml) or die("$configYaml: $!");
my $ffmpeg     = can_run('ffmpeg') or die("ffmpeg is not found");
my $mp4tags    = can_run('mp4tags');

# YAML ファイルの整形
if (0) {
    foreach my $f ( glob("${FindBin::RealBin}/config*") ) {
        say "$f";
        DumpFile( $f, LoadFile($f) );
    }
    exit;
}

my $ua       = LWP::UserAgent->new;
my $response = $ua->get( $config->{'RadiruConfig'} );
if ( !$response->is_success ) {
    die( $response->status_line );
}
my $radiruConfig = XMLin(
    $response->decoded_content,
    ForceArray => ['data'],
    GroupTags  => { 'stream_url' => 'data' },
    KeyAttr    => { 'data' => '+area' },
);
my $streamUrl = $radiruConfig->{'stream_url'};

my @areas         = keys( %{$streamUrl} );
my %apikeyToArea  = map { $streamUrl->{$_}{'apikey'} => $_ } @areas;
my %areaToAreaKey = map { $_ => $streamUrl->{$_}{'areakey'} } @areas;
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
my $outdir   = $argv[4] || $config->{'SavePath'}{$^O} || $ENV{'HOME'} || ".";
if ( $duration <= 0 || !grep( /^$area$/, @areas ) || !grep( /^$channel$/, @channels ) ) {
    die($helpMessage);
}
my $areaKey = $areaToAreaKey{$area};
my $endTime = $duration * 60 + time();
while ( ( my $restDuration = $endTime - time() ) > 0 ) {
    my $t        = localtime;
    my $postfix  = $t->ymd('') . '_' . $t->hms('');
    my $workfile = "${outdir}/.${title}_${postfix}.m4a";
    my $outfile  = "${outdir}/${title}_${postfix}.m4a";

    getProgramInfo( 'https:' . $radiruConfig->{'url_program_noa'},
        $areaKey, "${outdir}/${title}_${postfix}.yml" );
    getStream( $streamUrl->{$area}{ $channel . 'hls' },
        $restDuration + $config->{'ExtendSeconds'}, $workfile );
    writeTags( $title, $t, $workfile );
    chmod( 0666, $workfile );
    rename( $workfile, $outfile );

    # ダウンロード時間が再生時間より短いので終了時刻前にDL完了する。
    # 開始時10秒分, 終了時10秒分待機する。
    sleep( 10 + $config->{'ExtendSeconds'} );
}

# 番組情報ダウンロード
sub getProgramInfo {
    my $infoUrl = shift or return;
    my $areaKey = shift or return;
    my $file    = shift or return;
    $infoUrl =~ s/\{area\}/$areaKey/;
    my $res = $ua->get($infoUrl);
    my $info
        = try { $json->decode( $res->decoded_content ) } catch { $res->decoded_content };
    DumpFile( $file, $info );
}

# m4a ダウンロード
sub getStream {
    my $uri      = shift or return;
    my $duration = shift or return;
    my $file     = shift or return;
    my $cmd      = sprintf( '%s%s%s -y -i %s%s%s -bsf:a aac_adtstoasc -c copy -t %d %s%s%s',
        QUOTE, $ffmpeg, QUOTE, QUOTE, $uri, QUOTE, $duration, QUOTE, $file, QUOTE );
    my ( $success, $error_message, $full_buf, $stdout_buf, $stderr_buf )
        = run( command => $cmd, verbose => 0, timeout => 60 * 60 * 12 );
    my @messagesStdOut = @{$stdout_buf} <= 10 ? @{$stdout_buf} : splice( @{$stdout_buf}, -10 );
    my @messagesStdErr = @{$stderr_buf} <= 10 ? @{$stderr_buf} : splice( @{$stderr_buf}, -10 );

    if ( !$success ) {
        unlink($file);
        warn("Error:\n${error_message}\n") if $error_message;
        say "StdOut:\n" . unifyLf( join( "\n", @messagesStdOut ) );
        say "StdErr:\n" . unifyLf( join( "\n", @messagesStdErr ) );
        say "Failed to get stream";
        return 0;
    }
    return 1;
}

# mp4 タグ埋め込み
sub writeTags {
    my $title = shift or return;
    my $t     = shift or return;
    my $file  = shift or return;
    if ( !$mp4tags ) {
        return;
    }
    my $cmd = sprintf(
        '%s%s%s -song %s%s%s -genre %sradio%s -year %d %s%s%s',
        QUOTE, $mp4tags, QUOTE,    QUOTE, $title, QUOTE,
        QUOTE, QUOTE,    $t->year, QUOTE, $file,  QUOTE
    );
    my ( $success, $error_message, $full_buf, $stdout_buf, $stderr_buf )
        = run( command => $cmd, verbose => 0, timeout => 60 * 60 * 12 );
    my @messagesStdOut = @{$stdout_buf} <= 10 ? @{$stdout_buf} : splice( @{$stdout_buf}, -10 );
    my @messagesStdErr = @{$stderr_buf} <= 10 ? @{$stderr_buf} : splice( @{$stderr_buf}, -10 );
    if ( !$success ) {
        warn("Error:\n${error_message}\n") if $error_message;
        say "StdOut:\n" . unifyLf( join( "\n", @messagesStdOut ) );
        say "StdErr:\n" . unifyLf( join( "\n", @messagesStdErr ) );
        say "Failed to write tags";
        return 0;
    }
    return 1;
}

sub unifyLf {
    my $text = shift or return '';
    $text =~ s/\r\n/\n/g;
    $text =~ s/\r/\n/g;
    return $text;
}

# EOF
