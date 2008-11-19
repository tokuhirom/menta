package Email::MIME::Encodings;
use strict;
no strict 'refs';
use warnings;

$Email::MIME::Encodings::VERSION = "1.311";

use MIME::Base64;
use MIME::QuotedPrint;

sub identity { $_[0] }

for (qw(7bit 8bit binary)) {
    *{"encode_$_"} = *{"decode_$_"} = \&identity;
}

sub codec {
    my ($which, $how, $what) = @_;
    $how = lc $how;
    $how = "qp" if $how eq "quotedprint" or $how eq "quoted-printable";
    my $sub = $which."_".$how;
    if (not defined &$sub) {
        require Carp;
        Carp::croak("Don't know how to $which $how");
    }
    $sub->($what);
}

sub decode { return codec("decode", @_) }
sub encode { return codec("encode", @_) }

1;

=head1 NAME

Email::MIME::Encodings - A unified interface to MIME encoding and decoding

=head1 SYNOPSIS

  use Email::MIME::Encodings;
  my $encoded = Email::MIME::Encodings::encode(base64 => $body);
  my $decoded = Email::MIME::Encodings::decode(base64 => $encoded);

=head1 DESCRIPTION

This module simply wraps C<MIME::Base64> and C<MIME::QuotedPrint>
so that you can throw the contents of a C<Content-Transfer-Encoding>
header at some text and have the right thing happen.

=head1 PERL EMAIL PROJECT

This module is maintained by the Perl Email Project.

L<http://emailproject.perl.org/wiki/Email::MIME::Encodings>

=head1 AUTHOR

Simon Cozens, C<simon@cpan.org>

=head1 SEE ALSO

C<MIME::Base64>, C<MIME::QuotedPrint>, C<Email::MIME>.

=head1 COPYRIGHT AND LICENSE

Copyright 2004, Casey West F<<casey@geeknest.com>>.

Copyright 2003 by Simon Cozens

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
