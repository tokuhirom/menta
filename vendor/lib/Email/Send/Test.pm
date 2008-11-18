package Email::Send::Test;

=pod

=head1 NAME

Email::Send::Test - Captures emails sent via Email::Send for testing

=head1 SYNOPSIS

  # Load as normal
  use Email::Send;
  use Email::Send::Test;
  
  # Always clear the email trap before each test to prevent unexpected
  # results, and thus spurious test results.
  Email::Send::Test->clear;
  
  ### BEGIN YOUR CODE TO BE TESTED (example follows)
  my $sender = Email::Send->new({ mailer => 'Test' });
  $sender->send( $message );
  ### END YOUR CODE TO BE TESTED
  
  # Check that the number and type (and content) of mails
  # matched what you expect.
  my @emails = Email::Send::Test->emails;
  is( scalar(@emails), 1, 'Sent 1 email' );
  isa_ok( $emails[0], 'Email::MIME' );

=head1 DESCRIPTION

Email::Send::Test is a driver for use in testing applications that use
L<Email::Send> to send email.

To be able to use it in testing, you will need some sort of configuration
mechanism to specify the delivery method to be used, or some other way
that in your testing scripts you can convince your code to use "Test" as
the mailer, rather than "Sendmail" or another real mailer.

=head2 How does it Work

Email::Send::Test is a trap for emails. When an email is sent, it adds the
emails to an internal array without doing anything at all to them, and
returns success to the caller.

If your application sends one email, there will be one in the trap. If you
send 20, there will be 20, and so on.

A typical test will involve doing running some code that B<should> result
in an email being sent, and then checking in the trap to see if the
code did actually send out the email.

If you want you can get the emails out the trap and examine them. If you
only care that something got sent you can simply clear the trap and move
on to your next test.

=head2 The Email Trap

The email trap is a simple array fills with whatever is sent.

When you send an email, it is pushed onto the end of the array. You can
access the array directly if you wish, or use the methods provided.

=head1 METHODS

=cut

use 5.005;
use strict;

use vars qw{$VERSION};
BEGIN {
	$VERSION = '2.188';
}

# No longer allow direct access to the array
my @DELIVERIES = ();

# This mailer is always available
sub is_available { 1 }

=pod

=head2 send $message

As for every other L<Email::Send> mailer, C<send> takes the message to be
sent.

However, in our case there are no arguments of any value to us, and so they
are ignored.

It is worth nothing that we do NOTHING to check or alter the email. For
example, if we are passed C<undef> it ends up as is in the trap. In this
manner, you can see B<exactly> what was sent without any possible tampering
on the part of the testing mailer.

Of course, this doesn't prevent any tampering by Email::Send itself :)

Always returns true.

=cut

sub send {
  my ($self, $email, @rest) = @_;

  push @DELIVERIES, [ $self, $email, \@rest ];
	return 1;
}

=pod

=head2 emails

The C<emails> method is the prefered and recommended method of getting
access to the email trap.

In list context, returns the content of the trap array as a list.

In scalar context, returns the number of items in the trap.

=cut

sub emails {
  return scalar @DELIVERIES unless wantarray;
  return map { $_->[1] } @DELIVERIES;
}

=pod

=head2 clear

The C<clear> method resets the trap, emptying it.

It is recommended you always clear the trap before each
test to ensure any existing emails are removed and don't
create a spurious test result.

Always returns true.

=cut

sub clear {
	@DELIVERIES = ();
	return 1;
}

=head2 deliveries

This method returns a list of arrayrefs, one for each call to C<send> that has
been made.  Each arrayref is in the form:

  [ $mailer, $email, \@rest ]

The first element is the invocant on which C<send> was called.  The second is
the email that was given to C<send>.  The third is the rest of the arguments
given to C<send>.

=cut

sub deliveries {
  @DELIVERIES
}

1;

=pod

=head1 SUPPORT

All bugs should be filed via the CPAN bug tracker at

L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Email-Send-Test>

For other issues, or commercial enhancement or support, contact the author.

=head1 AUTHORS

Current maintainer: Ricardo SIGNES, <F<rjbs@cpan.org>>.

Original author: Adam Kennedy E<lt>cpan@ali.asE<gt>, L<http://ali.as/>

=head1 COPYRIGHT

Copyright (c) 2004 - 2005 Adam Kennedy. All rights reserved.
This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
