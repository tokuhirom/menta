package Email::MIME::ContentType;
# $Id: /my/pep/Email-MIME-ContentType/trunk/lib/Email/MIME/ContentType.pm 31133 2007-03-22T19:52:26.296283Z rjbs  $
use base 'Exporter';
use vars qw[
  $VERSION @EXPORT
  $STRICT_PARAMS
];
@EXPORT = qw(parse_content_type);
use strict;
use Carp;
$VERSION = '1.014';

$STRICT_PARAMS=1;

my $tspecials = quotemeta '()<>@,;:\\"/[]?=';
my $ct_default = 'text/plain; charset=us-ascii';
my $extract_quoted = 
    qr/(?:\"(?:[^\\\"]*(?:\\.[^\\\"]*)*)\"|\'(?:[^\\\']*(?:\\.[^\\\']*)*)\')/;

# For documentation, really:
{
  my $discrete  = qr/[^$tspecials]+/;
  my $composite = qr/[^$tspecials]+/;
  my $params    = qr/;.*/;

  sub parse_content_type { # XXX This does not take note of RFC2822 comments
      my $ct = shift;

      # If the header isn't there or is empty, give default answer.
      return parse_content_type($ct_default) unless defined $ct and length $ct;

      # It is also recommend (sic.) that this default be assumed when a
      # syntactically invalid Content-Type header field is encountered.
      return parse_content_type($ct_default)
          unless $ct =~ m[ ^ ($discrete) / ($composite) \s* ($params)? $ ]x;

      return {
          discrete   => lc $1,
          composite  => lc $2,
          attributes => _parse_attributes($3)
      };
  }
}

sub _parse_attributes {
    local $_ = shift;
    my $attribs = {};
    while ($_) {
        s/^;//;
        s/^\s+// and next;
        s/\s+$//;
        unless (s/^([^$tspecials]+)=//) {
          # We check for $_'s truth because some mail software generates a
          # Content-Type like this: "Content-Type: text/plain;"
          # RFC 1521 section 3 says a parameter must exist if there is a
          # semicolon.
          carp "Illegal Content-Type parameter $_" if $STRICT_PARAMS or $_;
          return $attribs;
        }
        my $attribute = lc $1;
        my $value = _extract_ct_attribute_value();
        $attribs->{$attribute} = $value;
    }
    return $attribs;
}

sub _extract_ct_attribute_value { # EXPECTS AND MODIFIES $_
    my $value;
    while ($_) { 
        s/^([^$tspecials]+)// and $value .= $1;
        s/^($extract_quoted)// and do {
            my $sub = $1; $sub =~ s/^["']//; $sub =~ s/["']$//;
            $value .= $sub;
        };
        /^;/ and last;
        /^([$tspecials])/ and do { 
            carp "Unquoted $1 not allowed in Content-Type!"; 
            return;
        }
    }
    return $value;
}

1;

__END__

=head1 NAME

Email::MIME::ContentType - Parse a MIME Content-Type Header

=head1 VERSION

version 1.013

  $Id: /my/pep/Email-MIME-ContentType/trunk/lib/Email/MIME/ContentType.pm 31133 2007-03-22T19:52:26.296283Z rjbs  $

=head1 SYNOPSIS

  use Email::MIME::ContentType;

  # Content-Type: text/plain; charset="us-ascii"; format=flowed
  my $ct = 'text/plain; charset="us-ascii"; format=flowed';
  my $data = parse_content_type($ct);

  $data = {
    discrete   => "text",
    composite  => "plain",
    attributes => {
      charset => "us-ascii",
      format  => "flowed"
    }
  };

=head1 FUNCTIONS

=head2 parse_content_type

This routine is exported by default.

This routine parses email content type headers according to section 5.1 of RFC
2045. It returns a hash as above, with entries for the discrete type, the
composite type, and a hash of attributes.

=head1 WARNINGS

This is not a valid content-type header, according to both RFC 1521 and RFC
2045:

  Content-Type: type/subtype;

If a semicolon appears, a parameter must.  C<parse_content_type> will carp if
it encounters a header of this type, but you can suppress this by setting
C<$Email::MIME::ContentType::STRICT_PARAMS> to a false value.  Please consider
localizing this assignment!

=head1 PERL EMAIL PROJECT

This module is maintained by the Perl Email Project.

L<http://emailproject.perl.org/wiki/Email::MIME::ContentType>

=head1 AUTHOR

Casey West, C<casey@geeknest.com>
Simon Cozens, C<simon@cpan.org>

=head1 SEE ALSO

L<Email::MIME>

=cut
