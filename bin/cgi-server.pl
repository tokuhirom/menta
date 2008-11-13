#!/usr/bin/perl
use strict;
use warnings;
use lib 'vendor/lib', 'lib';
require HTTP::Server::Simple::CGI;
use POSIX;
use HTTP::Response;

{
    package MENTA::BindSTDOUT::Tie;
    require Tie::Handle;
    use base qw/Tie::Handle/;
    use Carp;

    sub TIEHANDLE {
        my ($class, $bufref) = @_;
        bless {buf => $bufref}, $class;
    }

    sub WRITE {
        my $self = shift;
        ${$self->{buf}} .= shift;
    }

    sub READ { croak "このハンドルは読み込み専用です" }
    sub CLOSE { }
}

{
    package MENTA::Server;
    use base qw/HTTP::Server::Simple::CGI/;

    sub bind_stdout {
        my ($code, ) = @_;
        tie *STDOUT, 'MENTA::BindSTDOUT::Tie', \my $out;
        $code->();
        untie *STDOUT;
        $out;
    }

    sub handler {
        my $pid = fork();
        if ($pid) {
            close STDIN;
            close STDOUT;
            waitpid($pid, POSIX::WNOHANG);
        } elsif ($pid == 0) {
            chdir 'app';
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

MENTA::Server->new(5555)->run;

