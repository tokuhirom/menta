package t::Utils;
use strict;
use warnings;

sub import {
    my $pkg = caller(0);
    strict->import;
    warnings->import;
    no strict 'refs';
    *{"$pkg\::run_cgi"} = \&run_cgi;
}

sub run_cgi {
    my %args = @_;
    $ENV{CONTENT_LENGTH} = $args{CONTENT_LENGTH} || 0;
    $ENV{PATH_INFO} = $args{PATH_INFO} || '/';
    $ENV{QUERY_STRING} = $args{QUERY_STRING} || '';
    $ENV{HTTP_USER_AGENT} = $args{HTTP_USER_AGENT} || 'test';
    $ENV{REQUEST_METHOD} = $args{REQUEST_METHOD} || 'GET';

    my $out = bind_stdout(sub {
        package main;
        do './menta.cgi';
        die $@ if $@;
    });
}

{
    package MENTA::BindSTDOUT::Tie;
    require Tie::Handle;
    use base qw/Tie::Handle/;
    use Carp;

    sub TIEHANDLE {
        my ($class, $in, $outref) = @_;
        bless {out => $outref, in => $in, pos => 0}, $class;
    }

    sub WRITE {
        my $self = shift;
        ${$self->{out}} .= shift;
    }

    # $self->READ(buf, len, offset);
    # copy from IO::Scalar
    sub READ {
        my $self = $_[0];
        my $n    = $_[2];
        my $off  = $_[3] || 0;

        my $read = substr( $self->{in}, $self->{pos}, $n );
        $n = length($read);
        $self->{pos} += $n;
        ( $off ? substr( $_[1], $off ) : $_[1] ) = $read;
        return $n;
    }
    sub CLOSE { }
    sub BINMODE { }
}

sub bind_stdout {
    my ($code, ) = @_;
    my $in;
    read(STDIN, $in, $ENV{CONTENT_LENGTH});
    tie *STDOUT, 'MENTA::BindSTDOUT::Tie', $in, \my $out;
    $code->();
    untie *STDOUT;
    $out;
}


1;
