########################################################
#   Package for calling a MATLAB functon via socket
#   communication.
#
#   Dimitar Atanasov, 2010
#   datanasov@nbu.bg
#

package mapi;
use strict;
use Data::Dumper;
use String::Random qw(random_string);
use Compress::Zlib;
use MIME::Base64;
use IO::Socket::INET;
use Storable qw(freeze thaw);


########################################################
#
# Costructor
#
#   Create an empty object
#       my $self = {

#              Connection properties
#                 'host'       => Server host
#                 'port'       => Server port
#                 'timeout'    => Socket timeout

#              MATLAB properties
#                 'function'   => MATLAB expression, by
#                                   default undef,
#                 'args_in'    => hash with input arguments of the
#                                  function and their values
#                                  'NAME' => Value
#                                   by default undef,
#                 'args_out'   => array of output arguments of the
#                                   MATLAB expression
#                                   by default ['ans'],
#                 'output'     => Matlab object with results
#                 'plot'       => hash with plot properties if function is plot
#                                 $self->{'plot'}{'title'}
#                                 $self->{'plot'}{'xlabel'}
#                                 $self->{'plot'}{'ylabel'}
#                                 and so on will be passed to matlab
#                                 $self->{'plot'}{'type'} is file type
#                 'graph'      => returned graph file,



#######################################################
#
#   Constructor
#

sub new {
    my $class = shift;
    my $self = {
                'host'       => '127.0.0.1',
                'port'       => 7770,
                'function'   => undef,
                'args_in'    => undef,
                'args_out'   => ['ans'],
                'plot'       => undef,
                'graph'      => undef,
                'output'     => undef,
                'timeout'    => 5,
                };
    bless $self, $class;
    return $self;
};

#############################################################

sub connect
{
    my $self = shift;

    my $sock = IO::Socket::INET->new(
                                    Type     => SOCK_STREAM,
                                    Proto    => "tcp",
                                    PeerAddr => $self->{'host'},
                                    PeerPort => $self->{'port'},
                                    Timeout  => $self->{'timeout'},
                                    )
               or s_log( $@ );

    $self->{'socket'} = $sock;
}

#############################################################

sub send
{
    my $self = shift;

    if ( ! $self->{'socket'} )
    {
        die "Not connected to the server";
    }
    else
    {
         my %h = (
                'function'   => $self->{'function'},
                'args_in'    => $self->{'args_in'},
                'args_out'   => $self->{'args_out'},
                'plot'       => $self->{'plot'},
                 );

         my $msg = freeze \%h;
         my $sock = $self->{'socket'};

         my $id = 'T_'.random_string('cccccccc');
         $sock->write($id.'-'.sprintf('%09d',length($msg)));
         $sock->write($msg);

    }

}

#############################################################

sub receive {
    my $self = shift;
    my $sock = $self->{'socket'};
    my $msg;

    my $hdr;
    my $l = $sock->read($hdr,20);
    $hdr =~ /^(.+)-(\d+)$/;
    my $id = $1;
    my $len = $2;
    s_log(" Received resut $hdr for $id($len)");

    my $l = $sock->read($msg,$len);
    return if $l != $len;

    my $m = thaw $msg;
    $self->{'output'} = $m->{'output'};
    $self->{'plot'}   = $m->{'graph'};
}


#############################################################
sub s_log {
    my $msg = shift;
    open(my $F, ">>mapi.log");
    print STDERR $msg."\n";
    print $F $msg."\n";
}

#############################################################

1;