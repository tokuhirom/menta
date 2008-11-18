package Email::Send::Qmail;
use strict;

use File::Spec ();
use Return::Value;
use Symbol qw(gensym);

use vars qw[$QMAIL $VERSION];
$QMAIL   ||= q[qmail-inject];
$VERSION   = '2.15';

sub is_available {
    my $class = shift;


    return failure "No qmail found" unless $class->_find_qmail;
    return success;
}

sub _find_qmail {
    my $class = shift;

    my $sendmail;
    for my $dir (File::Spec->path) {
        if ( -x "$dir/$QMAIL" ) {
            $sendmail = "$dir/$QMAIL";
            last;
        }
    }
    return $sendmail;
}

sub send {
    my ($class, $message, @args) = @_;

    my $pipe = gensym;

    open $pipe, "| $QMAIL @args"
        or return failure "couldn't open pipe to qmail";

    print $pipe $message->as_string
        or return failure "couldn't send message to qmail";

    close $pipe
        or return failure "error when closing pipe to qmail";

    return success;
}

1;

__END__

=head1 NAME

Email::Send::Qmail - Send Messages using qmail-inject

=head1 SYNOPSIS

  use Email::Send;

  Email::Send->new({mailer => 'Qmail'})->send($message);

=head1 DESCRIPTION

This mailer for C<Email::Send> uses C<qmail-inject> to put a message in
the Qmail spool. It I<does not> try hard to find the executable. It just
calls C<qmail-inject> and expects it to be in your path. If that's not
the case, or you want to explicitly define the location of your
executable, alter the C<$Email::Send::Qmail::QMAIL> package variable.

  $Email::Send::Qmail::QMAIL = '/usr/sbin/qmail-inject';

Any arguments passed to C<send> will be passed to C<qmail-inject>.

=head1 SEE ALSO

L<Email::Send>,
L<perl>.

=head1 AUTHOR

Current maintainer: Ricardo SIGNES, <F<rjbs@cpan.org>>.

Original author: Casey West, <F<casey@geeknest.com>>.

=head1 COPYRIGHT

  Copyright (c) 2004 Casey West.  All rights reserved.
  This module is free software; you can redistribute it and/or modify it
  under the same terms as Perl itself.

=cut
