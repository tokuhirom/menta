use t::Utils;
use Path::Class;
use Test::More tests => 1;

my $size = 0;
dir('extlib')->recurse(
    callback => sub {
        my $f = shift;
        # return unless -f $f;
        return unless $f =~ m{ \.pm \z }msx;
        $size += $f->stat->size;
    }
);
cmp_ok $size, '<', 5 * 1024 * 1024, "5MB 以下である(${size})";

