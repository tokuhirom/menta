#!/usr/bin/perl
use strict;
use warnings;
use lib 'extlib', 'lib';
use Getopt::Long;
use Plack;
use Plack::Server::Standalone;

my $port = 5555;
GetOptions(
    'p|port=i' => \$port,
);

my $app = do 'menta.psgi';

my $server = Plack::Server::Standalone->new(port => $port);
$server->run($app);

