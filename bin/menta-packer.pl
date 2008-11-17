#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use lib 'vendor/lib', 'lib';
use MENTA::Packer;

binmode STDOUT, ':utf8';

MENTA::Packer->run( 'app' => 'out' );

