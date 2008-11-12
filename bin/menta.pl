#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use lib 'vender/lib/', 'lib';
use MENTA::Builder;

binmode STDOUT, ':utf8';

MENTA::Builder->run;

