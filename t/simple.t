use strict;
use warnings;
use Test::More tests => 1;
use t::Utils;

my $out = run_cgi();
like $out, qr!<title>MENTA</title>!;
