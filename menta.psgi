#!/usr/bin/perl
use File::Basename qw/dirname/;
BEGIN {
    my $base = dirname(__FILE__);
    unshift @INC, "$base/lib", "$base/cgi-extlib-perl/extlib";
};
use MENTA;
my $base = dirname(__FILE__);
MENTA->create_app(do "$base/config.pl");

