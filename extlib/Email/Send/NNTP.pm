package Email::Send::NNTP;
use strict;

use vars qw[$NNTP $VERSION];
use Net::NNTP;
use Return::Value;

$VERSION   = '2.04';

sub is_available {
    return   eval { require Net::NNTP }
           ? success
           : failure $@;
}

sub send {
    my ($class, $message, @args) = @_;
    eval { require Net::NNTP };
    if ( @_ > 1 ) {
        $NNTP->quit if $NNTP;
        $NNTP = Net::NNTP->new(@args);
        return failure unless $NNTP;
    }
    return failure unless $NNTP->post( $message->as_string );
    return success;
}

sub DESTROY {
    $NNTP->quit if $NNTP;
}

1;

__END__

=head1 NAME

Email::Send::NNTP - Post Messages to a News Server

=head1 SYNOPSIS

  use Email::Send;

  my $mailer = Email::Send->new({mailer => 'NNTP'});
  
  $mailer->mailer_args([Host => 'nntp.example.com']);
  
  $mailer->send($message);

=head1 DESCRIPTION

This is a mailer for C<Email::Send> that will post a message to a news server.
The message must be formatted properly for posting. Namely, it must contain a
I<Newsgroups:> header. At least the first invocation of C<send> requires
a news server arguments. After the first declaration the news server will
be remembered until such time as you pass another one in.

=head1 SEE ALSO

L<Email::Send>,
L<Net::NNTP>,
L<perl>.

=head1 AUTHOR

Current maintainer: Ricardo SIGNES, <F<rjbs@cpan.org>>.

Original author: Casey West, <F<casey@geeknest.com>>.

=head1 COPYRIGHT

  Copyright (c) 2004 Casey West.  All rights reserved.
  This module is free software; you can redistribute it and/or modify it
  under the same terms as Perl itself.

=cut
