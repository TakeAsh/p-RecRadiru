#!/usr/bin/perl
# Record 調布FM, FMさがみ
# usage: RecMms.pl <channel> <duration> [<title>] [<outdir>]

use strict;
use warnings;
use utf8;
use Encode;
use FindBin;
use YAML::Syck qw( Load LoadFile Dump DumpFile );
use LWP::UserAgent;
use XML::Simple qw(:strict);
use Time::Piece;
use File::Copy;

$YAML::Syck::ImplicitUnicode = 1;

my $charset = 'utf-8';    # utf-8, CP932

binmode( STDIN,  ":encoding($charset)" );
binmode( STDOUT, ":encoding($charset)" );
binmode( STDERR, ":encoding($charset)" );

my $path       = $FindBin::RealBin . '/';
my $configYaml = $path . 'config.yml';
my $config     = LoadFile($configYaml) or die("$configYaml: $!");

my @channels = keys( %{ $config->{'Channels'} } );

my $helpMessage
    = "usage: $0 <channel> <duration> [<title>] [<outdir>]\narea: "
    . "\nchannel: "
    . join( " | ", @channels )
    . "\nduration: minuites\n";

if ( @ARGV < 2 ) {
    die($helpMessage);
}

my @argv     = map { decode( $charset, $_ ) } @ARGV;
my $t        = localtime;
my $channel  = $argv[0];
my $duration = $argv[1];
my $title    = $argv[2] || ${channel};
my $outdir   = $argv[3] || $config->{'SavePath'} || $ENV{'HOME'} || ".";
if ( $duration <= 0 || !grep( /^$channel$/, @channels ) ) {
    die($helpMessage);
}
my $endTime = $duration * 60 + $config->{'ExtendSeconds'} + time();

my $pid = fork;
if ( !defined($pid) ) {
    die("Cannot fork: $!");
}

if ( !$pid ) {

    # Child Process
while ( ( my $restDuration = $endTime - time() ) > 0 ) {
my $postfix = $t->ymd('') . '_' . $t->hms('');
my $tmpfile = "${outdir}/.${title}_${postfix}.asf";
my $mplayerCmd = sprintf(
    '"%s" "%s" -dumpstream -dumpfile "%s" < /dev/null',
    $config->{'MplayerPath'},
    $config->{'Channels'}{$channel}, $tmpfile
);
    system( encode( $charset, $mplayerCmd ) );
}
}

# Parent Process
sleep( $duration * 60 + $config->{'ExtendSeconds'} );
kill( 'KILL', $pid );
chdir(${outdir});
my @tmpfiles = glob(".${title}_*.asf");
if ( !@tmpfiles ) {
    exit(1);
}
if ( !$config->{'FfmpegPath'} ) {
    foreach my $tmpfile (@tmpfiles){
        my $outfile = substr($tmpfile, 1);
    move( $tmpfile, $outfile );
    }
    exit;
}
foreach my $tmpfile (@tmpfiles){
    my $outfile = substr($tmpfile, 1);
my $ffmpegCmd = sprintf(
    '"%s" -loglevel error -vcodec copy -acodec copy -i "%s" "%s"',
    $config->{'FfmpegPath'},
    $tmpfile, $outfile
);
system( encode( $charset, $ffmpegCmd ) );
unlink($tmpfile);
}
if ( !$config->{'Mp4tagsPath'} ) {
    exit;
}
foreach my $tmpfile (@tmpfiles){
    my $outfile = substr($tmpfile, 1);
my $mp4tagsCmd = sprintf(
    '"%s" -song "%s" -genre "radio" -year %d %s',
    $config->{'Mp4tagsPath'},
    $title, $t->year, $outfile
);
system( encode( $charset, $mp4tagsCmd ) );
}

# EOF
