use strict;
use warnings;
use Test::More tests => 1;
use t::Utils;

my $out = run_cgi(
    PATH_INFO => '/goto_wassr'
);
is $out, join("\r\n", 'Status: 302', 'Location: http://wassr.jp/', '', '');

