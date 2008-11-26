package Class::Accessor::Lite;

use strict;

our $VERSION = '0.02';

sub mk_accessors {
    shift; # usage: Class::Accessor::Lite->mk_accessors(qw(...));
    no strict 'refs';
    my $pkg = caller(0);
    for my $n (@_) {
        *{$pkg . '::' . $n} = __m($n);
    }
}

sub __m {
    my $n = shift;
    sub {
        return $_[0]->{$n} if @_ == 1;
        return $_[0]->{$n} = $_[1] if @_ == 2;
        shift->{$n} = \@_;
    };
}

1;

__END__

=head1 NAME

Class::Accessor::Lite - a minimalistic variant of Class::Accessor

=head1 SYNOPSIS

package MyPackage;

use Class::Accessor::Lite;

Class::Accessor::Lite->mk_accessors(qw(foo bar));

=head1 DESCRIPTION

This is a minimalitic variant of C<Class::Accessor> and its alikes.

It is intended to be standalone and minimal, so that it can be copy & pasted into individual perl script files.

=head1 AUTHORS

Copyright (C) 2008 Kazuho Oku

=head1 LICENSE

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself, either Perl version 5.8.6 or, at your option, any later version of Perl 5 you may have available.

=head1 SEE ALSO

C<Class::Accessor>
