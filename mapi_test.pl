#!/usr/bin/perl

use mapi;

my $m = new mapi;
$m->connect();
$m->{'function'} = 'A = rand(10,10)';
$m->{'args_out'} = ['A'];
$m->send();
$m->receive();
