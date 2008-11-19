#!/usr/bin/perl
use strict;
use warnings;
use lib 'extlib', 'lib';
require HTTP::Server::Simple::CGI;
use POSIX;
use HTTP::Response;

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

    sub BINMODE { }
    sub CLOSE { }
}

{
    package MENTA::Server;
    use base qw/HTTP::Server::Simple::CGI/;

    sub bind_stdout {
        my ($code, ) = @_;
        my $in;
        read(STDIN, $in, $ENV{CONTENT_LENGTH} || 0);
        tie *STDOUT, 'MENTA::BindSTDOUT::Tie', $in, \my $out;
        $code->();
        untie *STDOUT;
        $out;
    }

    sub handler {
        my $pid = fork();
        if ($pid) {
            waitpid($pid, POSIX::WNOHANG);
        } elsif ($pid == 0) {
            my $out = bind_stdout(sub {
                package main;
                do './menta.cgi';
                die $@ if $@;
            });
            my $res = HTTP::Response->parse("HTTP/1.0 200 OK\r\n$out");
            if (my $status = $res->header('Status')) {
                $res->code($status);
                $res->message(HTTP::Status::status_message($status));
            }
            print $res->as_string;
            exit;
        } elsif (defined $pid) {
            die $!;
        }
    }
}

my $server = MENTA::Server->new(5555);
$server->run;

