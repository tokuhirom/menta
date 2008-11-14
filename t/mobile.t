use Test::More tests => 1;
use t::Utils;

my $out = run_cgi(
    PATH_INFO      => '/mobile',
    REQUEST_METHOD => 'GET',
    HTTP_USER_AGENT => 'UP.Browser/3.04-TS13 UP.Link/3.4.4'
);
like $out, qr/あなたのブラウザは EZweb です/;
