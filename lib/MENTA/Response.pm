package MENTA::Response;
use strict;
use warnings;
use HTTP::Headers::Fast;
Class::Accessor::Lite->mk_accessors(qw/code content headers/);

sub new {
    my ($class, %args) = @_;
    bless {
        code    => 200,
        content => '',
        headers => HTTP::Headers::Fast->new(),
        %args,
    }, $class;
}

sub header {
    my $self = shift;
    $self->headers->header(@_);
}

sub as_string {
    my $self = shift;
    my $CRLF = "\015\012";
    join(
        '',
        $self->headers->as_string($CRLF),
        $CRLF,
        $self->content
    );
}

sub length {
    my $self = shift;
    my $bytes = $self->content;
    utf8::encode($bytes);
    length $bytes;
}

1;
