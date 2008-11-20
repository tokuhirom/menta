package CGI::ExceptionManager;
use strict;
use warnings;
use 5.00800;
our $VERSION = '0.01';
use CGI::ExceptionManager::StackTrace;

sub detach { die bless [], 'CGI::ExceptionManager::Exception' }

sub run {
    my ($class, %args) = @_;

    my $err_info;
    local $SIG{__DIE__} = sub {
        my ($msg) = @_;
        if (ref $msg eq 'CGI::ExceptionManager::Exception') {
            undef $err_info;
        } else {
            $err_info = CGI::ExceptionManager::StackTrace->new($msg);
        }
        die;
    };
    local $@;
    eval {
        $args{callback}->();
        undef $err_info;
    };
    if ($err_info) {
        $err_info->output(
            powered_by => $args{powered_by} || __PACKAGE__,
            ($args{renderer} ? (renderer => $args{renderer}) : ())
        );
    }
}

1;
__END__

=encoding utf8

=head1 NAME

CGI::ExceptionManager - DebugScreen with detach!

=head1 SYNOPSIS

    use CGI::ExceptionManager;
    CGI::ExceptionManager->run(
        callback => sub {
            redirect("http://wassr.jp/");

            # do not reach here
        },
        powered_by => 'MENTA',
    );

    sub redirect {
        my $location = shift;
        print "Status: 302\n";
        print "Location: $location\n";
        print "\n";

        CGI::ExceptionManager::detach();
    }

=head1 DESCRIPTION

You can easy to implement DebugScreen and Detach architecture =)

=head1 METHODS

=over 4

=item detach

detach from current context.

=item run

    CGI::ExceptionManager->run(
        callback => \&code,
        powered_by => 'MENTA',
    );

run the new context.

You can specify your own renderer like following code:

    CGI::ExceptionManager->run(
        callback   => \&code,
        powered_by => 'MENTA',
        renderer   => sub {
        },
    );

=back

=head1 AUTHOR

Tokuhiro Matsuno E<lt>tokuhirom@gmail.comE<gt>

Kazuho Oku

=head1 SEE ALSO

L<Sledge::Plugin::DebugScreen>, L<http://kazuho.31tools.com/nanoa/nanoa.cgi>, L<http://gp.ath.cx/menta/>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
