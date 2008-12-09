use Test::More;
use t::Utils;
use lib 'extlib';
use UNIVERSAL::require;

do 'plugins/bundle.pl';

my %libs = MENTA::Plugin::Bundle::bundle_libs();
plan tests => scalar keys %libs;
no strict 'refs';
while (my ($key, $val) = each %libs) {
    $key->require or die $@;
    is ${"${key}::VERSION"}, $val, $key;
}

