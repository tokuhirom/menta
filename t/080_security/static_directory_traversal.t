use t::Utils;
use Test::More tests => 1;
use Path::Class;

# init
my $tmp = file('app/data/secret.txt');
my $fh = $tmp->openw;
$fh->print("THIS IS SECRET");
$fh->close();

# do test
my $out = run_cgi(
    PATH_INFO      => '/static/../data/secret.txt',
    REQUEST_METHOD => 'GET',
);

unlike $out, qr{THIS IS SECRET};

unlink 'app/data/secret.txt';
