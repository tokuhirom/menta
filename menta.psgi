#!/usr/bin/perl
BEGIN {
    unshift @INC, 'lib', 'cgi-extlib-perl/extlib';
};
use MENTA;
MENTA->create_app(do 'config.pl');

