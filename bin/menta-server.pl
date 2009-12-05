#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use File::Spec;
use lib File::Spec->catdir($FindBin::Bin, '..', 'cgi-extlib-perl', 'extlib');
use lib File::Spec->catdir($FindBin::Bin, '..', 'lib');
use Getopt::Long;
use Plack;
use Plack::Server::Standalone;
use Plack::Loader::Reloadable;
use Plack::Middleware::StackTrace;
use Plack::Middleware::AccessLog;
use Plack::Builder;
use Plack::Util;
use Plack::Loader;

my $port = 5555;
GetOptions(
    'p|port=i' => \$port,
);

# delay the build process for reloader
sub build(&;$) {
    my $block = shift;
    my $app   = shift || sub { };
    return sub { $block->($app->()) };
}

my $psgi = 'menta.psgi';
my $handler = build { Plack::Util::load_psgi $psgi };
my $loader = Plack::Loader::Reloadable->new(['app/controller/', 'lib', 'plugins', 'cgi-extlib-perl']);
$handler = build { Plack::Middleware::StackTrace->wrap($_[0]) } $handler;
$handler = build { Plack::Middleware::AccessLog->wrap($_[0], logger => sub { print STDERR @_ }) } $handler;
my $app = $handler;
my $server = $loader->load('Standalone', port => $port);
$server->run($app);

