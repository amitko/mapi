########################################################
#   Package for calling a MATLAB functon from Perl
#   Dimitar Atanasov, 2009
#   datanasov@nbu.bg
#

package Matlab;
use strict;
use Data::Dumper;
use String::Random qw(random_string);
use Compress::Zlib;
use MIME::Base64;


########################################################
#
# Costructor
#
#   Create an empty object
#       my $self = {
#                 'function'   => MATLAB expression, by
#                                   default undef,
#                 'args_in'    => hash with input arguments of the
#                                  function and their values
#                                  'NAME' => Value
#                                   by default undef,
#                 'args_out'   => array of output arguments of the
#                                   MATLAB expression
#                                   by default ['ans'],
#                 'call'       => string with complete MATLAB
#                                 expression, prepared during call
#                                 when calling shoud be undef,
#                 'output'     => hash with values of output arguments,
#                                 defined in args_out
#                 'ses_id'     => session id, by default 1,
#                 'rnd_id'     => random string, used in teporary fle names,
#                 'plot'       => hash with plot properties if function is plot
#                                 $self->{'plot'}{'title'}
#                                 $self->{'plot'}{'xlabel'}
#                                 $self->{'plot'}{'ylabel'}
#                                 and so on will be passed to matlab
#                                 $self->{'plot'}{'type'} is file type
#                 'graph'      => returned graph file,
#                 'img_file'   => name of temporary image file,
#                 'matlab_dir' => directory to matlab executable
#                 'server_wd'  => working directory of Matlab server
#                 'server_output'=> MATLAB APPLICATION SERVER output dir
#	          'toolbox_path' => path to additional matlab toolboxes


#######################################################
#
#   Constructor
#

sub new {
    my $class = shift;
    my $self = {
                'function'   => undef,
                'args_in'    => undef,
                'args_out'   => ['ans'],
                'call'       => undef,
                'output'     => undef,
                'ses_id'     => 1,
                'rnd_id'     => random_string('cccccccccc'),
                'plot'       => undef,
                'graph'      => undef,
                'img_file'   => undef,
                'sever_wd'         => '',
                };
    bless $self, $class;
    return $self;
};


########################################################
#
# Prepare MATLAB expression
#

sub prepare {
    my $self = shift;
    my $function = $self->{'function'};

    return undef if ! $function;

    my $call;
    $call .= "addpath(genpath('".$self->{'toolbox_path'}."'));\n" if $self->{'toolbox_path'};
    for my $arg ( keys %{ $self->{'args_in'} } ) {
        $call .= "$arg = ".$self->{'args_in'}{$arg}.";\n";
    }

    $call .= $function.";\n";

    for my $arg ( @{ $self->{'args_out'} } ) {
        $call .= "save ".$self->{'server_output'}.$self->{'rnd_id'}."_".$self->{'ses_id'}."_$arg $arg -ascii -double -tabs;\n";
    }

    $self->{'call'} = $call;
    return $self;
}



########################################################
#
# Prepare plot expression
#

sub prepare_plot {
    my $self = shift;

    # $self->{'plot'}{'title'}
    # $self->{'plot'}{'xlabel'}
    # $self->{'plot'}{'ylabel'}
    # and so on will be passed to matlab
    # $self->{'plot'}{'type'} is file type

    $self->{'plot'}{'type'} = 'jpg' if ! $self->{'plot'}{'type'};

    my $call;
    $call .= "addpath(genpath('".$self->{'toolbox_path'}."'));\n" if $self->{'toolbox_path'};

    for my $arg ( keys %{ $self->{'args_in'} } ) {
        $call .= "$arg = ".$self->{'args_in'}{$arg}.";\n";
    }


    $call .= "h = figure;\n" if ! exists $self->{'plot'}{'no_figure'};
    $call .= $self->{'function'}.";\n";

    for my $opt ( keys %{ $self->{'plot'} } ) {
        next if $opt eq 'type';
        next if $opt eq 'no_figure';
        if ( $self->{'plot'}{$opt} ne '' ) {
            $call .= $opt."(".$self->{'plot'}{$opt}.");\n";
        }
        else {
            $call .= $opt.";\n";
        }
    }

    my $file = $self->{'server_output'}.$self->{'rnd_id'}."_".$self->{'ses_id'}."_plot.".$self->{'plot'}{'type'};
    $call .= "saveas( h, '" .$file. "' , '". $self->{'plot'}{'type'} ."');\n";

    for my $arg ( @{ $self->{'args_out'} } ) {
        $call .= "save ".$self->{'server_output'}.$self->{'rnd_id'}."_".$self->{'ses_id'}."_$arg $arg -ascii -double -tabs;\n";
    }

    $self->{'img_file'} = $file;
    $self->{'call'}     = $call;

    return $self;
}


########################################################
#
# Get image file
#

sub get_image {
    my $self = shift;

    my $fl = 1;

    my $time_w = time();

    while ( $fl ) {
    if  ( ! open(my $F, $self->{'img_file'} ) ) {
        sleep(1);
        next;
    }
    else {
        $fl =0;
        binmode $F;

        my $T;

        while ( <$F> ) {
            $T .= $_;
        }

         $self->{'graph'} = encode_base64( Compress::Zlib::memGzip( $T ) );

        close($F);
        unlink($self->{'img_file'});
    }
    last if $time_w + 60*60 < time();
    }

    return $self;
}

########################################################
#
# Passing m file to the MATLAB APPLICATION SERVER
#

sub pass {
    my $self = shift;


    $self->prepare() if ! $self->{'call'};# and ! $self->{'plot'};
    $self->prepare_plot() if $self->{'plot'};

    my $file = $self->{'server_wd'}."in/".$self->{'rnd_id'}."_".$self->{'ses_id'}.".in";
    open(my $F, ">$file") or die "Can't write request $file";
    print $F $self->{'call'};
    close $F;
}


########################################################
#
# Picking results from the MATLAB APPLICATION SERVER
#

sub pick {
    my $self = shift;

    my %PARS = ();
    for my $k ( @{$self->{'args_out'}} ) {
       $PARS{$k}{'WAIT'} = 1;
       $PARS{$k}{'READY'} = 0;
    }



    my $time_w = time();
    while ( ! check_if_args_returned( $self ) ) {
        print ".";

        for my $k ( keys %{ $self->{'output'} } ) {

            next if $self->{'output'}{$k}{'READY'};

            my $file = $self->{'server_output'}.$self->{'rnd_id'}."_".$self->{'ses_id'}."_$k";

            if ( -e $file ) {
                open(my $F, $file ) or die "Can't load temporary file $file for variable file $k\n";
                my $value;
                while ( <$F> ) {
                    $value .= $_;
                }
                close($F);
                unlink($file);
                $self->{'output'}{$k}{'VALUE'} = $value;
                $self->{'output'}{$k}{'READY'} = 1;
                $self->{'output'}{$k}{'WAIT'} = 0;
            }
            else {
                next;
            }
        }
        sleep(1);
        last if $time_w + 60*60 < time();
    }
}


########################################################
#
# Check if results are ready
#

sub check_if_args_returned {
    my $self = shift;


    if ( ! $self->{'output'} ) {
     my %PARS = ();
     for my $k ( @{$self->{'args_out'}} ) {
        $PARS{$k}{'WAIT'} = 1;
        $PARS{$k}{'READY'} = 0;
        $PARS{$k}{'VALUE'} = undef;
     }
     $self->{'output'} = \%PARS;
    }
    else {
        my $ready;
        my $total;
        for my $k ( keys %{ $self->{'output'} } ) {
            $ready += 1 if $self->{'output'}{$k}{'READY'};
            $total += 1;
        }

        return 1 if $total == $ready;
    }
    return 0;
}


########################################################
#
# Start MATLAB APPLICATION SERVER
#

sub start_server {
    my $self = shift;

chdir ( $self->{'server_wd'} );
system( $self->{'matlab_dir'}.'matlab -nodisplay -nosplash -r msrv' );

}


########################################################
#
# Clear object
#

sub clear {
    my $self = shift;

    $self->{ 'function'  } = undef;
    $self->{ 'args_in'   } = undef;
    $self->{ 'args_out'  } = ['ans'];
    $self->{ 'call'      } = undef;
    $self->{ 'plot'      } = undef;
    $self->{ 'graph'     } = undef;
    $self->{ 'args_out'  } = ['ans'];
    $self->{ 'img_file'  } = undef;
    $self->{ 'output'    } = undef;
    $self->{'rnd_id'     } = random_string('cccccccccc');
    return $self;
}


1;
