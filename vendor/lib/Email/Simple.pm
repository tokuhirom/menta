package Email::Simple;

use 5.00503; # why? -- rjbs, 2007-04-01
use strict;
use Carp ();

use Email::Simple::Header;

$Email::Simple::VERSION = '2.004';
$Email::Simple::GROUCHY = 0;

# We are liberal in what we accept.
sub __crlf_re { qr/\x0a\x0d|\x0d\x0a|\x0a|\x0d/; }

=head1 NAME

Email::Simple - simple parsing of RFC2822 message format and headers

=head1 SYNOPSIS

  my $email = Email::Simple->new($text);

  my $from_header = $email->header("From");
  my @received = $email->header("Received");

  $email->header_set("From", 'Simon Cozens <simon@cpan.org>');

  my $old_body = $email->body;
  $email->body_set("Hello world\nSimon");

  print $email->as_string;

=head1 DESCRIPTION

C<Email::Simple> is the first deliverable of the "Perl Email Project."  The
Email:: namespace was begun as a reaction against the increasing complexity and
bugginess of Perl's existing email modules.  C<Email::*> modules are meant to
be simple to use and to maintain, pared to the bone, fast, minimal in their
external dependencies, and correct.

=head1 METHODS

=head2 new

  my $email = Email::Simple->new($message, \%arg);

This method parses an email from a scalar containing an RFC2822 formatted
message, and return an object.  C<$message> may be a reference to a message
string, in which case the string will be altered in place.  This can result in
significant memory savings.

If you want to create a message from scratch, you should use the plugin
L<Email::Simple::Creator>.

Valid arguments are:

  header_class - the class used to create new header objects
                 The named module is not 'require'-ed by Email::Simple!

=cut

sub new {
  my ($class, $text, $arg) = @_;
  $arg ||= {};

  Carp::croak 'Unable to parse undefined message' if ! defined $text;

  my $text_ref = ref $text ? $text : \$text;

  my ($pos, $mycrlf) = $class->_split_head_from_body($text_ref);

  my $self = bless { mycrlf => $mycrlf } => $class;

  my $head;
  if (defined $pos) {
    $head = substr $$text_ref, 0, $pos, '';
    substr($head, -(length $mycrlf)) = '';
  } else {
    $head     = $$text_ref;
    $text_ref = \'';
  }

  my $header_class = $arg->{header_class} || $self->default_header_class;

  $self->header_obj_set(
    $header_class->new(\$head, { crlf => $self->crlf })
  );

  $self->body_set($text_ref);

  return $self;
}

# Given the text of an email, return ($pos, $crlf) where $pos is the position
# at which the body text begins and $crlf is the type of newline used in the
# message.
sub _split_head_from_body {
  my ($self, $text_ref) = @_;

  # For body/header division, see RFC 2822, section 2.1
  my $crlf = $self->__crlf_re;

  if ($$text_ref =~ /(?:.*?($crlf))\1/gsm) {
    return (pos($$text_ref), $1);
  } else {

    # The body is, of course, optional.
    return (undef, "\n");
  }
}

=head2 header_obj

  my $header = $email->header_obj;

This method returns the object representing the email's header.  For the
interface for this object, see L<Email::Simple::Header>.

=cut

sub header_obj {
  my ($self) = @_;
  return $self->{header};
}

# Probably needs to exist in perpetuity for modules released during the "__head
# is tentative" phase, until we have a way to force modules below us on the
# dependency tree to upgrade.  i.e., never and/or in Perl 6 -- rjbs, 2006-11-28
BEGIN { *__head = \&header_obj }

=head2 header_obj_set

  $email->header_obj_set($new_header_obj);

This method substitutes the given new header object for the email's existing
header object.

=cut

sub header_obj_set {
  my ($self, $obj) = @_;
  $self->{header} = $obj;
}

=head2 header

  my @values = $email->header($header_name);
  my $first  = $email->header($header_name);

In list context, this returns every value for the named header.  In scalar
context, it returns the I<first> value for the named header.

=head2 header_set

    $email->header_set($field, $line1, $line2, ...);

Sets the header to contain the given data. If you pass multiple lines
in, you get multiple headers, and order is retained.

=head2 header_names

    my @header_names = $email->header_names;

This method returns the list of header names currently in the email object.
These names can be passed to the C<header> method one-at-a-time to get header
values. You are guaranteed to get a set of headers that are unique. You are not
guaranteed to get the headers in any order at all.

For backwards compatibility, this method can also be called as B<headers>.

=head2 header_pairs

  my @headers = $email->header_pairs;

This method returns a list of pairs describing the contents of the header.
Every other value, starting with and including zeroth, is a header name and the
value following it is the header value.

=cut

BEGIN {
  no strict 'refs';
  for my $method (qw(header header_set header_names header_pairs)) {
    *$method = sub { (shift)->header_obj->$method(@_) };
  }
  *headers = \&header_names;
}

=head2 body

Returns the body text of the mail.

=cut

sub body {
  my ($self) = @_;
  return (defined ${ $self->{body} }) ? ${ $self->{body} } : '';
}

=head2 body_set

Sets the body text of the mail.

=cut

sub body_set {
  my ($self, $text) = @_;
  my $text_ref = ref $text ? $text : \$text;
  $self->{body} = $text_ref;
  return;
}

=head2 as_string

Returns the mail as a string, reconstructing the headers.

=cut

sub as_string {
  my $self = shift;
  return $self->header_obj->as_string . $self->crlf . $self->body;
}

=head2 crlf

This method returns the type of newline used in the email.  It is an accessor
only.

=cut

sub crlf { $_[0]->{mycrlf} }

=head2 default_header_class

This returns the class used, by default, for header objects, and is provided
for subclassing.  The default default is Email::Simple::Header.

=cut

sub default_header_class { 'Email::Simple::Header' }

1;

__END__

=head1 CAVEATS

Email::Simple handles only RFC2822 formatted messages.  This means you cannot
expect it to cope well as the only parser between you and the outside world,
say for example when writing a mail filter for invocation from a .forward file
(for this we recommend you use L<Email::Filter> anyway).  For more information
on this issue please consult RT issue 2478,
L<http://rt.cpan.org/NoAuth/Bug.html?id=2478>.

=head1 PERL EMAIL PROJECT

This module is maintained by the Perl Email Project

L<http://emailproject.perl.org/wiki/Email::Simple>

=head1 AUTHORS

Simon Cozens originally wrote Email::Simple in 2003.  Casey West took over
maintenance in 2004, and Ricardo SIGNES took over maintenance in 2006.

=head1 COPYRIGHT AND LICENSE

Copyright 2004 by Casey West

Copyright 2003 by Simon Cozens

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
