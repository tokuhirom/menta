package Email::Simple::Header;

use strict;
use Carp ();

require Email::Simple;

$Email::Simple::Header::VERSION = '2.004';

=head1 NAME

Email::Simple::Header - the header of an Email::Simple message

=head1 SYNOPSIS

  my $email = Email::Simple->new($text);

  my $header = $email->head;
  print $header->as_string;

=head1 DESCRIPTION

This method implements the headers of an Email::Simple object.  It is a very
minimal interface, and is mostly for private consumption at the moment.

=head1 METHODS

=head2 new

  my $header = Email::Simple::Header->new($head, \%arg);

C<$head> is a string containing a valid email header, or a reference to such a
string.  If a reference is passed in, don't expect that it won't be altered.

Valid arguments are:

  crlf - the header's newline; defaults to CRLF

=cut

# We need to be able to:
#   * get all values by lc name
#   * produce all pairs, with case intact

sub new {
  my ($class, $head, $arg) = @_;

  my $head_ref = ref $head ? $head : \$head;

  my $self = { mycrlf => $arg->{crlf} || "\x0d\x0a", };

  my $headers = $class->_header_to_list($head_ref, $self->{mycrlf});

  #  for my $header (@$headers) {
  #    push @{ $self->{order} }, $header->[0];
  #    push @{ $self->{head}{ $header->[0] } }, $header->[1];
  #  }
  #
  #  $self->{header_names} = { map { lc $_ => $_ } keys %{ $self->{head} } };
  $self->{headers} = $headers;

  bless $self => $class;
}

sub _header_to_list {
  my ($self, $head, $mycrlf) = @_;

  my @headers;

  my $crlf = Email::Simple->__crlf_re;

  while ($$head =~ m/\G(.+?)$crlf/go) {
    local $_ = $1;
    if (s/^\s+// or not /^([^:]+):\s*(.*)/) {
      # This is a continuation line. We fold it onto the end of
      # the previous header.
      next if !@headers;  # Well, that sucks.  We're continuing nothing?

      $headers[-1] .= $headers[-1] ? " $_" : $_;
    } else {
      push @headers, $1, $2;
    }
  }

  return \@headers;
}

=head2 as_string

  my $string = $header->as_string(\%arg);

This returns a stringified version of the header.

=cut

# RFC 2822, 3.6:
# ...for the purposes of this standard, header fields SHOULD NOT be reordered
# when a message is transported or transformed.  More importantly, the trace
# header fields and resent header fields MUST NOT be reordered, and SHOULD be
# kept in blocks prepended to the message.

sub as_string {
  my ($self, $arg) = @_;
  $arg ||= {};

  my $header_str = '';

  my $headers = $self->{headers};

  my $fold_arg = {
    # at     => (exists $arg->{fold_at} ? $arg->{fold_at} : $self->default_fold_at),
    # indent => (exists $arg->{fold_indent} ? $arg->{fold_indent} : $self->default_fold_indent),
    at     => $self->_default_fold_at,
    indent => $self->_default_fold_indent,
  };

  for (my $i = 0; $i < @$headers; $i += 2) {
    my $header = "$headers->[$i]: $headers->[$i + 1]";

    $header_str .= lc $headers->[$i] eq 'content-type'
                 ? $header . $self->crlf
                 : $self->_fold($header, $fold_arg);
  }

  return $header_str;
}

=head2 header_names

This method returns the unique header names found in this header, in no
particular order.

=cut

sub header_names {
  my $headers = $_[0]->{headers};

  my %seen;
  grep  { !$seen{ lc $_ }++ }
    map { $headers->[ $_ * 2 ] } 0 .. int($#$headers / 2);
}

=head2 header_pairs

This method returns all the field/value pairs in the header, in the order that
they appear in the header.

=cut

sub header_pairs {
  my ($self) = @_;

  return @{ $self->{headers} };
}

=head2 header

  my $first_value = $header->header($field);
  my @all_values  = $header->header($field);

This method returns the value or values of the given header field.  If the
named field does not appear in the header, this method returns false.

=cut

sub header {
  my ($self, $field) = @_;

  my $headers  = $self->{headers};
  my $lc_field = lc $field;

  if (wantarray) {
    return map { @$headers[ $_ * 2 + 1 ] }
      grep { lc $headers->[ $_ * 2 ] eq $lc_field } 0 .. int($#$headers / 2);
  } else {
    for (0 .. int($#$headers / 2)) {
      return $headers->[ $_ * 2 + 1 ] if lc $headers->[ $_ * 2 ] eq $lc_field;
    }
    return;
  }
}

=head2 header_set

  $header->header_set($field => @values);

This method updates the value of the given header.  Existing headers have their
values set in place.  Additional headers are added at the end.

=cut

# Header fields are lines composed of a field name, followed by a colon (":"),
# followed by a field body, and terminated by CRLF.  A field name MUST be
# composed of printable US-ASCII characters (i.e., characters that have values
# between 33 and 126, inclusive), except colon.  A field body may be composed
# of any US-ASCII characters, except for CR and LF.

# However, a field body may contain CRLF when used in header "folding" and
# "unfolding" as described in section 2.2.3.

sub header_set {
  my ($self, $field, @data) = @_;

  # I hate this block. -- rjbs, 2006-10-06
  if ($Email::Simple::GROUCHY) {
    Carp::croak "field name contains illegal characters"
      unless $field =~ /^[\x21-\x39\x3b-\x7e]+$/;
    Carp::carp "field name is not limited to hyphens and alphanumerics"
      unless $field =~ /^[\w-]+$/;
  }

  my $headers = $self->{headers};

  my $lc_field = lc $field;
  my @indices = grep { lc $headers->[$_] eq $lc_field }
    map { $_ * 2 } 0 .. int($#$headers / 2);

  if (@indices > @data) {
    my $overage = @indices - @data;
    splice @{$headers}, $_, 2 for reverse @indices[ -$overage .. -1 ];
    pop @indices for (1 .. $overage);
  } elsif (@data > @indices) {
    my $underage = @data - @indices;
    for (1 .. $underage) {
      push @$headers, $field, undef;  # temporary value
      push @indices, $#$headers - 1;
    }
  }

  for (0 .. $#indices) {
    $headers->[ $indices[$_] + 1 ] = $data[$_];
  }

  return wantarray ? @data : $data[0];
}

=head2 crlf

This method returns the newline string used in the header.

=cut

sub crlf { $_[0]->{mycrlf} }

# =head2 fold
# 
#   my $folded = $header->fold($line, \%arg);
# 
# Given a header string, this method returns a folded version, if the string is
# long enough to warrant folding.  This method is used internally.
# 
# Valid arguments are:
# 
#   at      - fold lines to be no longer than this length, if possible
#             if given and false, never fold headers
#   indent  - indent lines with this string
# 
# =cut

sub _fold {
  my ($self, $line, $arg) = @_;
  $arg ||= {};

  $arg->{at} = $self->_default_fold_at unless exists $arg->{at};

  return $line . $self->crlf unless $arg->{at} and $arg->{at} > 0;

  my $limit  = ($arg->{at} || $self->_default_fold_at) - 1;

  return $line . $self->crlf if length $line <= $limit;

  $arg->{indent} = $self->_default_fold_indent unless exists $arg->{indent};

  my $indent = $arg->{indent} || $self->_default_fold_indent;

  # We know it will not contain any new lines at present
  my $folded = "";
  while ($line) {
    if ($line =~ s/^(.{0,$limit})(\s|\z)//) {
      $folded .= $1 . $self->crlf;
      $folded .= $indent if $line;
    } else {
      # Basically nothing we can do. :(
      $folded .= $line . $self->crlf;
      last;
    }
  }

  return $folded;
}

# =head2 default_fold_at
# 
# This method (provided for subclassing) returns the default length at which to
# try to fold header lines.  The default default is 78.
# 
# =cut

sub _default_fold_at { 78 }

# =head2 default_fold_indent
# 
# This method (provided for subclassing) returns the default string used to
# indent folded headers.  The default default is a single space.
# 
# =cut

sub _default_fold_indent { " " }

=head1 PERL EMAIL PROJECT

This module is maintained by the Perl Email Project

L<http://emailproject.perl.org/wiki/Email::Simple::Header>

=head1 COPYRIGHT AND LICENSE

Copyright 2006-2007 by Ricardo SIGNES

Copyright 2004 by Casey West

Copyright 2003 by Simon Cozens

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
