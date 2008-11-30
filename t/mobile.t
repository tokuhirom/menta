use Test::More tests => 1;
use t::Utils;
use Encode;
use utf8;

my $out = run_cgi(
    PATH_INFO      => '/demo/mobile',
    REQUEST_METHOD => 'GET',
    HTTP_USER_AGENT => 'UP.Browser/3.04-TS13 UP.Link/3.4.4'
);
like decode('cp932', $out), qr/あなたのブラウザは EZweb です/;

