use strict;
use warnings;
use Test::More tests => 2;
use t::Utils;

my $out = run_cgi(
    PATH_INFO => '/demo/goto_wassr'
);
like $out, qr!Location: http://wassr.jp/!;
like $out, qr!Status: 302!;

