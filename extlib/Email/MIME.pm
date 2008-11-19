use 5.006;
use strict;
use warnings;

package Email::MIME;
use base qw(Email::Simple);

use Email::MIME::ContentType;
use Email::MIME::Encodings;
use Carp;

=head1 NAME

Email::MIME - Easy MIME message parsing.

=head1 VERSION

version 1.861

 $Id: MIME.pm 780 2007-07-20 03:22:05Z rjbs@cpan.org $

=cut

our $VERSION = '1.861';

sub new {
  my $self = shift->SUPER::new(@_);
  $self->{ct} = parse_content_type($self->content_type);
  $self->parts;
  return $self;
}

sub as_string {
  my $self = shift;
  return $self->__head->as_string
    . ($self->{mycrlf} || "\n")  # XXX: replace with ->crlf
    . $self->body_raw;
}

sub parts {
  my $self = shift;

  $self->fill_parts unless $self->{parts};

  my @parts = @{ $self->{parts} };
  @parts = $self unless @parts;
  return @parts;
}

sub subparts {
  my ($self) = @_;

  $self->fill_parts unless $self->{parts};
  my @parts = @{ $self->{parts} };
  return @parts;
}

sub fill_parts {
  my $self = shift;
  if ( $self->{ct}{discrete} eq "multipart"
    or $self->{ct}{discrete} eq "message")
  {
    $self->parts_multipart;
  } else {
    $self->parts_single_part;
  }
  return $self;
}

sub body {
  my $self = shift;
  my $body = $self->SUPER::body;
  my $cte  = $self->header("Content-Transfer-Encoding");
  return $body unless $cte;
  if (!$self->force_decode_hook and $cte =~ /^7bit|8bit|binary/i) {
    return $body;
  }

  $body = $self->decode_hook($body) if $self->can("decode_hook");

  # For S/MIME, etc.
  $cte =~ s/;.+//;

  $body = Email::MIME::Encodings::decode($cte, $body);
  return $body;
}

sub parts_single_part {
  my $self = shift;
  $self->{parts} = [];
  return $self;
}

sub body_raw {
  return $_[0]->{body_raw} || $_[0]->SUPER::body;
}

sub parts_multipart {
  my $self     = shift;
  my $boundary = $self->{ct}->{attributes}->{boundary};
  return $self->parts_single_part unless $boundary;

  $self->{body_raw} = $self->SUPER::body;

  # rfc1521 7.2.1
  my ($body, $epilogue) = split /^--\Q$boundary\E--\s*$/sm, $self->body_raw, 2;

  my @bits = split /^--\Q$boundary\E\s*$/sm, ($body || '');

  $self->SUPER::body_set(undef);

  # This is a horrible hack, although it's debateable whether it was better
  # or worse when it was $self->{body} = shift @bits ... -- rjbs, 2006-11-27
  $self->SUPER::body_set(shift @bits) if ($bits[0] || '') !~ /.*:.*/;

  my $bits = @bits;

  my @parts;
  for my $bit (@bits) {
    $bit =~ s/\A[\n\r]+//smg;
    my $email = (ref $self)->new($bit);
    push @parts, $email;
  }

  $self->{parts} = \@parts;

  return @{ $self->{parts} };
}

sub force_decode_hook { 0 }
sub decode_hook       { return $_[1] }
sub content_type      { scalar shift->header("Content-type"); }

sub header {
  my $self   = shift;
  my @header = $self->SUPER::header(@_);
  foreach my $header (@header) {
    next unless $header =~ /=\?/;
    $header = $self->_header_decode($header);
  }
  return wantarray ? (@header) : $header[0];
}
*_header_decode =
  eval { require Encode }
  ? \&_header_decode_encode
  : do {
  require MIME::Words;
  \&_header_decode_mimewords;
  };

sub _header_decode_encode { Encode::decode("MIME-Header", $_[1]) }
sub _header_decode_mimewords { MIME::Words::decode_mimewords($_[1]) }

sub debug_structure {
  my ($self, $level) = @_;
  $level ||= 0;
  my $rv = " " x (5 * $level);
  $rv .= "+ " . $self->content_type . "\n";
  my @parts = $self->parts;
  if (@parts > 1) { $rv .= $_->debug_structure($level + 1) for @parts; }
  return $rv;
}

my %gcache;

sub filename {
  my ($self, $force) = @_;
  return $gcache{$self} if exists $gcache{$self};

  my $dis = $self->header("Content-Disposition") || '';
  my $attrs = $dis =~ s/^.*?;//
    ? Email::MIME::ContentType::_parse_attributes($dis)
    : {};
  my $name = $attrs->{filename}
    || $self->{ct}{attributes}{name};
  return $name if $name or !$force;
  return $gcache{$self} = $self->invent_filename(
    $self->{ct}->{discrete} . "/" . $self->{ct}->{composite});
}

my $gname = 0;

sub invent_filename {
  my ($self, $ct) = @_;
  require MIME::Types;
  my $type = MIME::Types->new->type($ct);
  my $ext = $type && (($type->extensions)[0]);
  $ext ||= "dat";
  return "attachment-$$-" . $gname++ . ".$ext";
}

1;

__END__

=head1 SYNOPSIS

  use Email::MIME;
  my $parsed = Email::MIME->new($message);

  my @parts = $parsed->parts; # These will be Email::MIME objects, too.
  my $decoded = $parsed->body;
  my $non_decoded = $parsed->body_raw;

  my $content_type = $parsed->content_type;

=head1 DESCRIPTION

This is an extension of the L<Email::Simple> module, to handle MIME
encoded messages. It takes a message as a string, splits it up into its
constituent parts, and allows you access to various parts of the
message. Headers are decoded from MIME encoding.

=head1 NOTE

This is an alpha release, designed to stimulate discussion on the API,
which may change in future releases. Please send me comments about any
features you think C<Email::MIME> should have. Note that I expect most
things to be driven by subclassing and mix-ins.

=head1 METHODS

Please see L<Email::Simple> for the base set of methods. It won't take
very long. Added to that, you have:

=head2 parts

This returns a list of C<Email::MIME> objects reflecting the parts of the
message. If it's a single-part message, you get the original object back.

In scalar context, this method returns the number of parts.

=head2 subparts

This returns a list of C<Email::MIME> objects reflecting the parts of the
message.  If it's a single-part message, this method returns an empty list.

In scalar context, this method returns the number of subparts.

=head2 body

This decodes and returns the body of the object. For top-level objects
in multi-part messages, this is highly likely to be something like "This
is a multi-part message in MIME format."

=head2 body_raw

This returns the body of the object, but doesn't decode the transfer
encoding.

=head2 decode_hook

This method is called before the L<Email::MIME::Encodings> C<decode> method, to
decode the body of non-binary messages (or binary messages, if the
C<force_decode_hook> method returns true).  By default, this method does
nothing, but subclasses may define behavior.

This method could be used to implement the decryption of content in secure
email, for example.

=head2 content_type

This is a shortcut for access to the content type header.

=head2 filename

This provides the suggested filename for the attachment part. Normally
it will return the filename from the headers, but if C<filename> is
passed a true parameter, it will generate an appropriate "stable"
filename if one is not found in the MIME headers.

=head2 invent_filename

  my $filename = Email::MIME->invent_filename($content_type);

This routine is used by C<filename> to generate filenames for attached files.
It will attempt to choose a reasonable extension, falling back to F<dat>.

=head2 debug_structure

  my $description = $email->debug_structure;

This method returns a string that describes the structure of the MIME entity.
For example:

  + multipart/alternative; boundary="=_NextPart_2"; charset="BIG-5"
    + text/plain
    + text/html

=head1 TODO

All of the Email::MIME-specific guts should move to a single entry on the
object's guts.  This will require changes to both Email::MIME and
L<Email::MIME::Modifier>, sadly.

=head1 SEE ALSO

L<Email::Simple>, L<Email::MIME::Modifier>, L<Email::MIME:Creator>.

=head1 PERL EMAIL PROJECT

This module is maintained by the Perl Email Project

L<http://emailproject.perl.org/wiki/Email::MIME>

=head1 AUTHOR

Casey West, C<casey@geeknest.com>

Simon Cozens, C<simon@cpan.org> (retired)

You may distribute this module under the terms of the Artistic or GPL
licenses.

=head1 THANKS

This module was generously sponsored by Best Practical
(http://www.bestpractical.com/) and Pete Sergeant.

=cut
