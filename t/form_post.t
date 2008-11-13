use strict;
use warnings;
use Test::More tests => 1;
use t::Utils;

my $out = run_cgi(
    PATH_INFO      => '/form',
    REQUEST_METHOD => 'GET',
    QUERY_STRING   => 'r=foo'
);
like $out, qr/パラメータ: foo/;

