package MENTA::Request;
use strict;
use warnings;
use CGI::Simple;

sub new {
    my ($class, $env) = @_;
    bless { env => $env }, $class;
}

sub hostname { $_[0]->{env}->{HTTP_HOST} || $_[0]->{env}->{SERVER_HOST} }
sub protocol { $_[0]->{env}->{SERVER_PROTOCOL} || 'HTTP/1.0' }
sub method   { $_[0]->{env}->{HTTP_METHOD} || 'GET' }

sub param {
    my $self = shift;
    local *STDIN = $self->{env}->{'psgi.input'};
    local %ENV = %{$self->{env}};
    $self->{cs} ||= CGI::Simple->new();
    $self->{cs}->param(@_);
}
sub upload {
    my $self = shift;
    local *STDIN = $self->{env}->{'psgi.input'};
    local %ENV = %{$self->{env}};
    $self->{cs} ||= CGI::Simple->new();
    $self->{cs}->upload(@_);
}
sub header {
    my ($self, $key) = @_;
    $key = uc $key;
    $key =~ s/-/_/;
    $self->{env}->{'HTTP_' . $key} || $self->{env}->{'HTTPS_' . $key};
}
sub headers {
    my ($self) = @_;
    $self->{headers} ||= do {
        require "HTTP/Headers.pm";
        my $headers = HTTP::Headers->new;
        for my $key (grep /^HTTPS?_/, keys %{$self->{env}}) {
            my $k = uc $key;
               $k =~ s/^HTTPS?_//;
               $k =~ s/_/-/;
            $headers->header($k, $self->{env}->{$key});
        }
        $headers;
    };
}

1;
