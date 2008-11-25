package MENTA::Context;
use strict;
use warnings;
use base qw/Class::Accessor::Fast/;
use MENTA::Response;

__PACKAGE__->mk_accessors(qw/config plugin_stash/);

sub new {
    my ($pkg, %args) = @_;
    bless {
        response     => MENTA::Response->new(),
        plugin_stash => {},
        %args,
    }, $pkg;
}

sub config { shift->{config} }

sub request {
    my $self = shift;
    unless ( defined $self->{request}) {
        main::require_once('MENTA/CGI.pm');
        $self->{request} = CGI::Simple->new();
    }
    $self->{request};
}

sub response {
    my $self = shift;
    $self->{response};
}
sub res { shift->response(@_) }

1;
