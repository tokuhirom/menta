use strict;
## no critic RequireUseWarnings
package Return::Value;
# vi:et:sw=4 ts=4

use vars qw[$VERSION @EXPORT];  ## no critic Export
$VERSION = '1.302';
@EXPORT  = qw[success failure];

use base qw[Exporter];
use Carp ();

=head1 NAME

Return::Value - Polymorphic Return Values

=head1 VERSION

version 1.302

 $Id: /my/cs/projects/return/trunk/lib/Return/Value.pm 28007 2006-11-14T22:21:03.864745Z rjbs  $

=head1 SYNOPSIS

Used with basic function-call interface:

  use Return::Value;
  
  sub send_over_network {
      my ($net, $send) = @_:
      if ( $net->transport( $send ) ) {
          return success;
      } else {
          return failure "Was not able to transport info.";
      }
  }
  
  my $result = $net->send_over_network(  "Data" );
  
  # boolean
  unless ( $result ) {
      # string
      print $result;
  }

Or, build your Return::Value as an object:
  
  sub build_up_return {
      my $return = failure;
      
      if ( ! foo() ) {
          $return->string("Can't foo!");
          return $return;
      }
      
      if ( ! bar() ) {
          $return->string("Can't bar");
          $return->prop(failures => \@bars);
          return $return;
      }
      
      # we're okay if we made it this far.
      $return++;
      return $return; # success!
  }

=head1 DESCRIPTION

Polymorphic return values are really useful.  Often, we just want to know if
something worked or not.  Other times, we'd like to know what the error text
was.  Still others, we may want to know what the error code was, and what the
error properties were.  We don't want to handle objects or data structures for
every single return value, but we do want to check error conditions in our code
because that's what good programmers do.

When functions are successful they may return true, or perhaps some useful
data.  In the quest to provide consistent return values, this gets confusing
between complex, informational errors and successful return values.

This module provides these features with a simple API that should get you what
you're looking for in each contex a return value is used in.

=head2 Attributes

All return values have a set of attributes that package up the information
returned.  All attributes can be accessed or changed via methods of the same
name, unless otherwise noted.  Many can also be accessed via overloaded
operations on the object, as noted below.

=over 4

=item type

A value's type is either "success" or "failure" and (obviously) reflects
whether the value is returning success or failure.

=item errno

The errno attribute stores the error number of the return value.  For
success-type results, it is by default undefined.  For other results, it
defaults to 1.

=item string

The value's string attribute is a simple message describing the value.

=item data

The data attribute stores a reference to a hash or array, and can be used as a
simple way to return extra data.  Data stored in the data attribute can be
accessed by dereferencing the return value itself.  (See below.)

=item prop

The most generic attribute of all, prop is a hashref that can be used to pass
an arbitrary number of data structures, just like the data attribute.  Unlike
the data attribute, though, these structures must be retrived via method calls.

=back

=head1 FUNCTIONS

The functional interface is highly recommended for use within functions
that are using C<Return::Value> for return values.  It's simple and
straightforward, and builds the entire return value in one statement.

=over 4

=cut

# This hack probably impacts performance more than I'd like to know, but it's
# needed to have a hashref object that can deref into a different hash.
# _ah($self,$key, [$value) sets or returns the value for the given key on the
# $self blessed-ref

sub _ah {
    my ($self, $key, $value) = @_;
    my $class = ref $self;
    bless $self => "ain't::overloaded";
    $self->{$key} = $value if @_ > 2;
    my $return = $self->{$key};
    bless $self => $class;
    return $return;
}

sub _builder {
    my %args = (type => shift);
    $args{string} = shift if (@_ % 2);
    %args = (%args, @_);

    $args{string} = $args{type} unless defined $args{string};

    $args{errno}  = ($args{type} eq 'success' ? undef : 1)
        unless defined $args{errno};

    __PACKAGE__->new(%args);
}

=item success

The C<success> function returns a C<Return::Value> with the type "success".

Additional named parameters may be passed to set the returned object's
attributes.  The first, optional, parameter is the string attribute and does
not need to be named.  All other parameters must be passed by name.

 # simplest possible case
 return success;

=cut

sub success { _builder('success', @_) }

=pod

=item failure

C<failure> is identical to C<success>, but returns an object with the type
"failure"

=cut

sub failure { _builder('failure', @_) }

=pod

=back

=head1 METHODS

The object API is useful in code that is catching C<Return::Value> objects.

=over 4

=item new

  my $return = Return::Value->new(
      type   => 'failure',
      string => "YOU FAIL",
      prop   => {
          failed_objects => \@objects,
      },
  );

Creates a new C<Return::Value> object.  Named parameters can be used to set the
object's attributes.

=cut

sub new {
    my $class = shift;
    bless { type => 'failure', string => q{}, prop => {}, @_ } => $class;
}

=pod

=item bool

  print "it worked" if $result->bool;

Returns the result in boolean context: true for success, false for failure.

=item prop

  printf "%s: %s',
    $result->string, join ' ', @{$result->prop('strings')}
      unless $result->bool;

Returns the return value's properties. Accepts the name of
a property retured, or returns the properties hash reference
if given no name.

=item other attribute accessors

Simple accessors exist for the object's other attributes: C<type>, C<errno>,
C<string>, and C<data>.

=cut

sub bool { _ah($_[0],'type') eq 'success' ? 1 : 0 }

sub type {
    my ($self, $value) = @_;
    return _ah($self, 'type') unless @_ > 1;
    Carp::croak "invalid result type: $value"
        unless $value eq 'success' or $value eq 'failure';
    return _ah($self, 'type', $value);
};

foreach my $name ( qw[errno string data] ) {
    ## no critic (ProhibitNoStrict)
    no strict 'refs';
    *{$name} = sub {
        my ($self, $value) = @_;
        return _ah($self, $name) unless @_ > 1;
        return _ah($self, $name, $value);
    };
}

sub prop {
    my ($self, $name, $value) = @_;
    return _ah($self, 'prop')          unless $name;
    return _ah($self, 'prop')->{$name} unless @_ > 2;
    return _ah($self, 'prop')->{$name} = $value;
}

=pod

=back

=head2 Overloading

Several operators are overloaded for C<Return::Value> objects. They are
listed here.

=over 4

=item Stringification

  print "$result\n";

Stringifies to the string attribute.

=item Boolean

  print $result unless $result;

Returns the C<bool> representation.

=item Numeric

Also returns the C<bool> value.

=item Dereference

Dereferencing the value as a hash or array will return the value of the data
attribute, if it matches that type, or an empty reference otherwise.  You can
check C<< ref $result->data >> to determine what kind of data (if any) was
passed.

=cut

use overload
    '""'   => sub { shift->string  },
    'bool' => sub { shift->bool },
    '=='   => sub { shift->bool   == shift },
    '!='   => sub { shift->bool   != shift },
    '>'    => sub { shift->bool   >  shift },
    '<'    => sub { shift->bool   <  shift },
    'eq'   => sub { shift->string eq shift },
    'ne'   => sub { shift->string ne shift },
    'gt'   => sub { shift->string gt shift },
    'lt'   => sub { shift->string lt shift },
    '++'   => sub { _ah(shift,'type','success') },
    '--'   => sub { _ah(shift,'type','failure') },
    '${}'  => sub { my $data = _ah($_[0],'data'); $data ? \$data : \undef },
    '%{}'  => sub { ref _ah($_[0],'data') eq 'HASH'  ? _ah($_[0],'data') : {} },
    '@{}'  => sub { ref _ah($_[0],'data') eq 'ARRAY' ? _ah($_[0],'data') : [] },
    fallback => 1;

=pod

=back

=head1 TODO

No plans!

=head1 AUTHORS

Casey West, <F<casey@geeknest.com>>.

Ricardo Signes, <F<rjbs@cpan.org>>.

=head1 COPYRIGHT

  Copyright (c) 2004-2006 Casey West and Ricardo SIGNES.  All rights reserved.
  This module is free software; you can redistribute it and/or modify it under
  the same terms as Perl itself.

=cut

"This return value is true.";

__END__
