use strict;
use warnings;
use Test::More tests => 1;
use t::Utils;

my $out = run_psgi(
    PATH_INFO      => '/robots.txt',
);
is $out->[0], 404;

