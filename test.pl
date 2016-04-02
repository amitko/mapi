use Matlab;
use Data::Dumper;
use strict;

my $m = Matlab->new();

my %hi = (
            'A' => 10,
            'B' => 5,
        );
my @ho = ('N');

$m->{'server_wd'} = '/home/dimitar/my/matlab/my_tools/msrv';
$m->{'matlab_dir'} = '/usr/local/matlab2008b/bin/';
$m->{'server_output'} = '/home/dimitar/my/matlab/my_tools/msrv/output';
#$m->start_server();

$m->{'args_in'} = \%hi;
$m->{'args_out'} = \@ho;
$m->{'function'} = 'N=randn(A,B)';


$m->pass();
$m->pick();

$m->clear();

$m->{'plot'}{'type'} = 'jpg';
$m->{'plot'}{'title'} = "'Random test'";
$m->{'plot'}{'xlabel'} = "'Random x'";
$m->{'plot'}{'ylabel'} = "'Random y'";
$m->{'plot'}{'legend'} = "'r1','r2','r3','r4','r5'";
$m->{'function'} = 'plot(randn(A,B))';
$m->{'args_in'} = \%hi;
$m->{'args_out'} = \@ho;
$m->pass();
$m->get_image();

#print Dumper($m);

 open(my $F, '>1.jpg');
 print $F $m->{'graph'};
 close($F);
