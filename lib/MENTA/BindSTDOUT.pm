package MENTA::BindSTDOUT;
use strict;
use warnings;

{
    package MENTA::BindSTDOUT::Tie;
    require Tie::Handle;
    use base qw/Tie::Handle/;
    use Carp;

    sub TIEHANDLE {
        my ($class, $bufref) = @_;
        bless {buf => $bufref}, $class;
    }

    sub WRITE {
        my $self = shift;
        ${$self->{buf}} .= shift;
    }

    sub READ { croak "This handle is readonly" }
    sub CLOSE { }
}

sub bind {
    my ($class, $code) = @_;
    tie *STDOUT, 'MENTA::BindSTDOUT::Tie', \my $out;
    $code->();
    untie *STDOUT;
    $out;
}

1;
