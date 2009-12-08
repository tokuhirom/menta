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
use Plack::Middleware::Lint;
use Plack::Builder;
use Plack::Util;
use Plack::Loader;

my $port = 5555;
my $env = "development";
GetOptions(
    'p|port=i' => \$port,
    'docroot=s' => \my $docroot,
    "E|env=s"      => \$env,
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
if (is_devel()) {
    $handler = build { Plack::Middleware::StackTrace->wrap($_[0]) } $handler;
    $handler = build { Plack::Middleware::Lint->wrap($_[0]) } $handler;
    $handler = build { Plack::Middleware::AccessLog->wrap($_[0], logger => sub { print STDERR @_ }) } $handler;
}
if ($docroot) {
    $handler = build {
        my $app = $_[0];
        sub {
            my $env = $_[0];
            my $sn = $env->{SCRIPT_NAME};
            $env->{SCRIPT_NAME} = $docroot . $sn;
            $app->($env);
        }
    }
    $handler;
}
my $app = $handler;
my $server = $loader->load(is_devel() ? 'Standalone::Prefork' : 'Standalone', port => $port);
$server->run($app);

sub is_devel { $env eq 'development' }

