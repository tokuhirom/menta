#!/usr/bin/perl
use strict;
use warnings;
use lib 'vendor/lib', 'lib';
require HTTP::Server::Simple::CGI;
use POSIX;
use MENTA::BindSTDOUT;
use HTTP::Response;

{
    package MENTA::Server;
    use base qw/HTTP::Server::Simple::CGI/;
    sub handle_request {
        my $pid = fork();
        if ($pid) {
            waitpid($pid, POSIX::WNOHANG);
        } elsif ($pid == 0) {
            system "$^X bin/menta.pl";
            chdir 'out';
            my $out = MENTA::BindSTDOUT->bind(sub {
                do './index.cgi';
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

