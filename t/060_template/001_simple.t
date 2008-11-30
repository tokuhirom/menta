use strict;
use warnings;
use Test::More tests => 2;
use MENTA::Template;

sub foo { 'bar' }
sub escape_html { $_[0] }

my $mt = MENTA::Template->new;
$mt->parse(<<'...');
?= foo()
...
$mt->build();
my $code = eval $mt->code();
ok !$@, $mt->code();
my $got = $code->();
is $got, 'bar';

