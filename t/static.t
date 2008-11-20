use Test::More tests => 1;
use t::Utils;

my $out_cgi = run_cgi(
    PATH_INFO      => '/',
);
if ($out_cgi =~ m{type="text/javascript"\s+src="([^"]+)"}) {
    my $src = $1;
    my $out_js = run_cgi(
        PATH_INFO      => "/$src",
    );
    like $out_js, qr/John Resig/;
} else {
    die "cannot find js source";
}

