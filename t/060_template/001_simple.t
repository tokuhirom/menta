use strict;
use warnings;
use Test::More tests => 1;
use MENTA::Template;

sub foo { 'bar' }

my $mt = MENTA::Template->new;
$mt->parse(<<'...');
?= foo()
...
$mt->build();
my $got = eval $mt->code();
is $got, 'bar';

