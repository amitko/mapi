#!/usr/bin/perl
########################################################
#   Package for processing a MATLAB functons via socket
#   communication.
#
#   Dimitar Atanasov, 2010
#   datanasov@nbu.bg
#

use strict;
use IO::Socket::INET;
use Data::Dumper;
use Storable qw(freeze thaw);
use Matlab;

our $LISTEN_PORT = shift || 7770;
our $ALLOWED_HOST = shift || '127.0.0.1';
our $WORKING_DIR = shift || '';

my $SERVER = IO::Socket::INET->new(  Proto     => 'tcp',
                                     LocalPort => $LISTEN_PORT,
                                     Listen    => 5,
                                     ReuseAddr => 1,
                                   );

if( ! $SERVER )
  {
    die "fatal: cannot open server port $LISTEN_PORT: $!" ;
  }

while ( 4 )  {

  my $CL = $SERVER->accept();

  my $cl_host = $CL->peerhost();
  my $cl_port = $CL->peerport();

  $CL->autoflush(1);

  s_log("connection from $cl_host:$cl_port");

  if ($cl_host ne $ALLOWED_HOST ) {
    s_log("!!!!: connection request from unallowed host ($cl_host)");
    $CL->close();
  }
  else {
    my $hdr;
    my $l = $CL->read($hdr,20);
    $hdr =~ /^(.+)-(\d+)$/;

    my $id = $1;
    my $len = $2;

    $SIG{CHLD} = "IGNORE";

    s_log("Received message: $id($len)") if $id;

    my $pid  = process_client($CL,$id,$len);

    s_log("Forked process: $pid") if $pid;
  }

}

close( $SERVER );

#############################################################
sub s_log {
    my $msg = shift;
    open(my $F, ">>tcp.log");
    print STDERR $msg."\n";
    print $F $msg."\n";
    close($F);
}

#############################################################

sub process_client {
    my $CL = shift;
    my $id = shift;
    my $len = shift;

    my $pid = fork();

    if( ! defined $pid ) {
        die "fork failed: $!";
    }
    return $pid if $pid;

    my $msg;
    my $l = $CL->read($msg,$len);

    my $mapi = thaw $msg;

    my $mat = new Matlab;
    $mat->{'function'} = $mapi->{'function'};
    $mat->{'args_in'}  = $mapi->{'args_in'};
    $mat->{'args_out'} = $mapi->{'args_out'};
    $mat->{'plot'}     = $mapi->{'plot'};
    $mat->{'ses_id'}   = $pid;
    $mat->{'rnd_id'}   = $id;


    $mat->{'server_wd'} = $WORKING_DIR;
    $mat->{'server_output'} = $WORKING_DIR.'output/';

    s_log("Processing massage (".$mat->{'rnd_id'}.") => ".Dumper($mapi));


    $mat->pass();
    $mat->pick();
    $mat->get_image() if $mat->{'plot'};

    s_log("Processed massage (".$mat->{'rnd_id'}.")");

    my %mt = (
              'output' => $mat->{'output'},
              'graph'  => $mat->{'graph'},
              );

    my $r_msg = freeze \%mt;

    $CL->write($mat->{'rnd_id'}.'-'.sprintf( '%09d', length($r_msg) ) );
    $CL->write($r_msg);
    exit 0;

}

#############################################################

