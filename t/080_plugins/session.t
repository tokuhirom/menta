use Test::More tests => 1;
use t::Utils;

my $out_cgi = run_cgi(
    PATH_INFO      => '/demo/session',
);
unlike $out_cgi, qr/Can't locate object method/;
