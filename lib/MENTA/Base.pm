package MENTA::Base;
use strict;
use warnings;
use MENTA;
use MENTA::Injector;
use MENTA::Controller::Base;

sub import {
    strict->import;
    warnings->import;
    utf8->import;

    MENTA::Injector->inject;
}

1;
