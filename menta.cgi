#!/usr/bin/perl
BEGIN {
    unshift @INC, 'lib', 'cgi-extlib-perl/extlib';
};
use MENTA;
MENTA->run_menta(do 'config.pl');

