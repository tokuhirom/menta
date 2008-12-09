package CGI::ExceptionManager::StackTrace::HTTPEngine;
use strict;
use warnings;
use base qw/CGI::ExceptionManager::StackTrace/;

sub output {
    my ($self, %args) = @_;
    
    warn $self->{message};

    my $res = HTTP::Engine::Response->new(
        status => 500,
    );
    $res->headers->content_type('text/html; charset=utf-8');
    $res->body(
        do {
            my $body = $args{renderer} ? $args{renderer}->($self, %args) : $self->as_html(%args);
            utf8::encode($body);
            $body;
        }
    );
    return $res;
}

1;
