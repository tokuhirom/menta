use strict;
use warnings;
use Test::More tests => 2;
use t::Utils;

my $out_cgi = run_cgi(
    PATH_INFO      => '/demo/bbs_sqlite',
);
like $out_cgi, qr/Status: 200/;
unlike $out_cgi, qr/Error trace/;
