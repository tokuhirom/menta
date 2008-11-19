package CGI::ExceptionManager;
use strict;
use warnings;
use 5.00800;
our $VERSION = '0.01';
use CGI::ExceptionManager::StackTrace;

sub detach { die { finished => 1 } }

sub run {
    my ($class, %args) = @_;

    my $err_info;
    local $SIG{__DIE__} = sub {
        my ($msg) = @_;
        if (ref $msg eq 'HASH' && $msg->{finished}) {
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
        );
    }
}

1;
__END__

=encoding utf8

=head1 NAME

CGI::ExceptionManager -

=head1 SYNOPSIS

    use CGI::ExceptionManager;
    CGI::ExceptionManager->run(
        callback => sub {
            print "Content-Type: text/html\r\n\r\n";
            print "ktkr!\n";

            CGI::ExceptionManager->detach();
        },
        powered_by => 'MENTA',
    );

=head1 DESCRIPTION

Just a Proof of Concept.

=head1 AUTHOR

Tokuhiro Matsuno E<lt>tokuhirom@gmail.comE<gt>

Kazuho Oku

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
