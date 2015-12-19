#!/usr/bin/perl
# Record NHK Net Radio らじる★らじる
# usage: RecRadiru.pl <area> <channel> <duration> [<title>] [<outdir>]

use strict;
use warnings;
use utf8;
use Encode;
use FindBin;
use YAML::Syck qw( Load LoadFile Dump DumpFile );
use LWP::UserAgent;
use XML::Simple qw(:strict);
use Time::Piece;

$YAML::Syck::ImplicitUnicode = 1;

my $charset = "utf-8";

#my $charset = "CP932";

binmode( STDIN,  ":encoding($charset)" );
binmode( STDOUT, ":encoding($charset)" );
binmode( STDERR, ":encoding($charset)" );

my @channels = qw( r1 r2 fm );

my $path       = $FindBin::RealBin . '/';
my $configYaml = $path . 'config.yml';
my $config     = LoadFile($configYaml) or die("$configYaml: $!");

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

my @areas  = keys( %{$streamUrl} );
my %areas2 = ();
foreach my $key (@areas) {
    $areas2{ $streamUrl->{$key}{'apikey'} } = $key;
}
my $helpMessage
    = "usage: $0 <area> <channel> <duration> [<title>] [<outdir>]\narea: "
    . join( " | ", map { $areas2{$_} } sort( keys(%areas2) ) )
    . "\nchannel: "
    . join( " | ", @channels )
    . "\nduration: minuites\n";

if ( @ARGV < 3 ) {
    die($helpMessage);
}
my @argv     = map { decode( $charset, $_ ) } @ARGV;
my $t        = localtime;
my $area     = $argv[0];
my $channel  = $argv[1];
my $duration = $argv[2];
my $title    = ( $argv[3] || "${area}_${channel}" ) . '_' . $t->ymd('') . '_' . $t->hms('');
my $outdir   = $argv[4] || $config->{'SavePath'} || $ENV{'HOME'} || ".";
if ( $duration <= 0 || !grep( /^$area$/, @areas ) || !grep( /^$channel$/, @channels ) ) {
    die($helpMessage);
}
my ( $rtmp, $playpath ) = split( /\/live\//, $streamUrl->{$area}{$channel} );
my $cmd = sprintf(
    '%s --rtmp %s --swfVfy %s --live --stop %d -o "%s"',
    $config->{'RtmpDumpPath'},
    $streamUrl->{$area}{$channel},
    $config->{'SwfVfy'}, $duration * 60 + $config->{'ExtendSeconds'},
    "${outdir}/${title}.m4a"
);
system($cmd);
my $exitCode = $? >> 8;
print $exitCode == 0
    ? "Success\n"
    : "Failed: $exitCode\n";

# EOF