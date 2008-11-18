package Email::Send;
use strict;

use vars qw[$VERSION];
$VERSION   = '2.192';

use Email::Simple;
use Module::Pluggable
  search_path => 'Email::Send',
  except      => $Email::Send::__plugin_exclusion;
use Return::Value;
use Scalar::Util ();

=head1 NAME

Email::Send - Simply Sending Email

=head1 SYNOPSIS

  use Email::Send;

  my $message = <<'__MESSAGE__';
  To: recipient@example.com
  From: sender@example.com
  Subject: Hello there folks
  
  How are you? Enjoy!
  __MESSAGE__

  my $sender = Email::Send->new({mailer => 'SMTP'});
  $sender->mailer_args([Host => 'smtp.example.com']);
  $sender->send($message);
  
  # more complex
  my $bulk = Email::Send->new;
  for ( qw[SMTP Sendmail Qmail] ) {
      $bulk->mailer($_) and last if $bulk->mailer_available($_);
  }

  $bulk->message_modifier(sub {
      my ($sender, $message, $to) = @_;
      $message->header_set(To => qq[$to\@geeknest.com])
  });
  
  my @to = qw[casey chastity evelina casey_jr marshall];
  my $rv = $bulk->send($message, $_) for @to;

=head1 DESCRIPTION

This module provides a very simple, very clean, very specific interface
to multiple Email mailers. The goal of this software is to be small
and simple, easy to use, and easy to extend.

=head2 Constructors

=over 4

=item new

  my $sender = Email::Send->new({
      mailer      => 'NNTP',
      mailer_args => [ Host => 'nntp.example.com' ],
  });

Create a new mailer object. This method can take parameters for any of the data
properties of this module. Those data properties, which have their own accessors,
are listed under L<"Properties">.

=back

=head2 Properties

=over 4

=item mailer

The mailing system you'd like to use for sending messages with this object.
This is not defined by default. If you don't specify a mailer, all available
plugins will be tried when the C<send> method is called until one succeeds.

=item mailer_args

Arguments passed into the mailing system you're using.

=item message_modifier

If defined, this callback is invoked every time the C<send> method is called
on an object. The mailer object will be passed as the first argument. Second,
the actual C<Email::Simple> object for a message will be passed. Finally, any
additional arguments passed to C<send> will be passed to this method in the
order they were recieved.

This is useful if you are sending in bulk.

=back

=cut

sub new {
    my ($class, $args) = @_;
    $args->{mailer_args} ||= [];
    my %plugins = map {
        my ($short_name) = /^Email::Send::(.+)/;
        ($short_name, $_);
    } $class->plugins;
    $args->{_plugin_list} = \%plugins;
    return bless $args => $class;
}

BEGIN {
  for my $field (qw(mailer mailer_args message_modifier _plugin_list)) {
    my $code = sub {
      return $_[0]->{$field} unless @_ > 1;
      my $self = shift;
      $self->{$field} = (@_ == 1 ? $_[0] : [@_]);
    };

    no strict 'refs';
    *$field = $code;
  }
}

=head2 METHODS

=over 4

=item send

  my $result = $sender->send($message, @modifier_args);

Send a message using the predetermined mailer and mailer arguments. If you
have defined a C<message_modifier> it will be called prior to sending.

The first argument you pass to send is an email message. It must be in some
format that C<Email::Abstract> can understand. If you don't have
C<Email::Abstract> installed then sending as plain text or an C<Email::Simple>
object will do.

Any remaining arguments will be passed directly into your defined
C<message_modifier>.

=cut

sub send {
    goto &_send_function unless eval { $_[0]->isa('Email::Send') };
    my ($self, $message, @args) = @_;

    my $simple = $self->_objectify_message($message);
    return failure "No message found." unless $simple;

    $self->message_modifier->(
        $self, $simple,
        @args,
    ) if $self->message_modifier;

    if ( $self->mailer ) {
        return $self->_send_it($self->mailer, $simple);
    }

    return $self->_try_all($simple);
}

=item all_mailers

  my @available = $sender->all_mailers;

Returns a list of availabe mailers. These are mailers that are
installed on your computer and register themselves as available.

=cut

sub all_mailers {
    my ($self) = @_;
    my @mailers;
    for ( keys %{$self->_plugin_list} ) {
        push @mailers, $_ if $self->mailer_available($_);
    }
    return @mailers;
}

=item mailer_available

  # is SMTP over SSL avaialble?
  $sender->mailer('SMTP')
    if $sender->mailer_available('SMTP', ssl => 1);

Given the name of a mailer, such as C<SMTP>, determine if it is
available. Any additional arguments passed to this method are passed
directly to the C<is_available> method of the mailer being queried.

=back

=cut

sub mailer_available {
  my ($self, $mailer, @args) = @_;

  my $invocant = $self->_mailer_invocant($mailer);

  return $invocant unless $invocant;

  $invocant->can('is_available')
    or return failure "Mailer $mailer doesn't report availability.";

  my $test = $invocant->is_available(@args);
  return $test unless $test;
  return success;
}

sub _objectify_message {
    my ($self, $message) = @_;

    return undef unless defined $message;
    return $message if UNIVERSAL::isa($message, 'Email::Simple');
    return Email::Simple->new($message) unless ref($message);
    return Email::Abstract->cast($message => 'Email::Simple')
      if eval { require Email::Abstract };
    return undef;
}

sub _mailer_invocant {
  my ($self, $mailer) = @_;

  return $mailer if Scalar::Util::blessed($mailer);

  # is the mailer a plugin given by short name?
  my $package = exists $self->_plugin_list->{$mailer}
               ? $self->_plugin_list->{$mailer}
               : $mailer;

  eval "require $package" or return failure "$@";

  return $package;
}

sub _send_it {
    my ($self, $mailer, $message) = @_;
    my $test = $self->mailer_available($mailer);
    return $test unless $test;

    my $invocant = $self->_mailer_invocant($mailer);

    return $invocant->send($message, @{$self->mailer_args});
}

sub _try_all {
    my ($self, $simple) = @_;
    foreach ( $self->all_mailers ) {
      my $sent = $self->_send_it($_, $simple);
      return $sent if $sent;
    }
    return failure "Unable to send message.";
}

# Classic Interface.

sub import {
    no strict 'refs';
    *{(caller)[0] . '::send'} = __PACKAGE__->can('_send_function');
}

sub _send_function {
    my ($mailer, $message, @args) = @_;
    __PACKAGE__->new({
        mailer => $mailer,
        mailer_args => \@args,
    })->send($message);
}

1;

__END__

=head2 Writing Mailers

  package Email::Send::Example;

  sub is_available {
      eval { use Net::Example }
  }

  sub send {
      my ($class, $message, @args) = @_;
      use Net::Example;
      Net::Example->do_it($message) or return;
  }
  
  1;

Writing new mailers is very simple. If you want to use a short name
when calling C<send>, name your mailer under the C<Email::Send> namespace.
If you don't, the full name will have to be used. A mailer only needs
to implement a single function, C<send>. It will be called from
C<Email::Send> exactly like this.

  Your::Sending::Package->send($message, @args);

C<$message> is an Email::Simple object, C<@args> are the extra
arguments passed into C<Email::Send::send>.

Here's an example of a mailer that sends email to a URL.

  package Email::Send::HTTP::Post;
  use strict;

  use vars qw[$AGENT $URL $FIELD];
  use Return::Value;
  
  sub is_available {
      eval { use LWP::UserAgent }
  }

  sub send {
      my ($class, $message, @args);

      require LWP::UserAgent;

      if ( @args ) {
          my ($URL, $FIELD) = @args;
          $AGENT = LWP::UserAgent->new;
      }
      return failure "Can't send to URL if no URL and field are named"
          unless $URL && $FIELD;
      $AGENT->post($URL => { $FIELD => $message->as_string });
      return success;
  }

  1;

This example will keep a UserAgent singleton unless new arguments are
passed to C<send>. It is used by calling C<Email::Send::send>.

  my $sender = Email::Send->new({ mailer => 'HTTP::Post' });
  
  $sender->mailer_args([ 'http://example.com/incoming', 'message' ]);

  $sender->send($message);
  $sender->send($message2); # uses saved $URL and $FIELD

=head1 SEE ALSO

L<Email::Simple>,
L<Email::Abstract>,
L<Email::Send::IO>,
L<Email::Send::NNTP>,
L<Email::Send::Qmail>,
L<Email::Send::SMTP>,
L<Email::Send::Sendmail>,
L<perl>.

=head1 PERL EMAIL PROJECT

This module is maintained by the Perl Email Project.

L<http://emailproject.perl.org/wiki/Email::Send>

=head1 AUTHOR

Current maintainer: Ricardo SIGNES, <F<rjbs@cpan.org>>.

Original author: Casey West, <F<casey@geeknest.com>>.

=head1 COPYRIGHT

  Copyright (c) 2005 Casey West.  All rights reserved.
  This module is free software; you can redistribute it and/or modify it
  under the same terms as Perl itself.

=cut
