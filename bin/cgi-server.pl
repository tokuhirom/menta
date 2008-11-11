#!/usr/bin/perl
use strict;
use warnings;
use lib 'vender/lib';
require HTTP::Server::Simple::CGI;
use POSIX;

{
    package MENTA::Server;
    use base qw/HTTP::Server::Simple::CGI/;
    sub handle_request {
        my $pid = fork();
        if ($pid) {
            waitpid($pid, POSIX::WNOHANG);
        } elsif ($pid == 0) {
            system 'bin/menta.pl';
            do 'out/index.cgi';
            die $@ if $@;
            exit;
        } elsif (defined $pid) {
            die $!;
        } 
    }
}

MENTA::Server->new(5555)->run;

