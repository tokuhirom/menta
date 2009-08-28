use strict;
use warnings;
use Test::More tests => 2;
use t::Utils;

my $out = run_cgi(
    PATH_INFO      => '/demo/form',
    REQUEST_METHOD => 'GET',
    QUERY_STRING   => 'r=foo'
);
like $out, qr/\br\s*:\s*"foo"/;

$out = run_cgi(
    PATH_INFO      => '/demo/form2',
    REQUEST_METHOD => 'GET',
    QUERY_STRING   => 'r=foo&r=bar'
);
like $out, qr/\br\s*:\s*"foo"\s*<br\s+\/>.*r\s*:\s*"bar"\s*<br\s+\/>/sm;
