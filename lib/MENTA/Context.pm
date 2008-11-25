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
        MENTA::Util::require_once('MENTA/CGI.pm');
        $self->{request} = CGI::Simple->new();
    }
    $self->{request};
}

sub response {
    my $self = shift;
    $self->{response};
}
sub res { shift->response(@_) }

sub mobile_agent {
    my $self = shift;
    $self->{'HTTP::MobileAgent'} ||= do {
        MENTA::Util::require_once('HTTP/MobileAgent.pm');
        HTTP::MobileAgent->new();
    };
}

1;
