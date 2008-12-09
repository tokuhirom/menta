package MENTA::Context;
use strict;
use warnings;
Class::Accessor::Lite->mk_accessors(qw/config plugin_stash request/);

sub new {
    my ($pkg, %args) = @_;
    bless {
        plugin_stash => {},
        %args,
    }, $pkg;
}

sub mobile_agent {
    my $self = shift;
    $self->{'HTTP::MobileAgent'} ||= do {
        MENTA::Util::require_once('HTTP/MobileAgent.pm');
        HTTP::MobileAgent->new();
    };
}

1;
