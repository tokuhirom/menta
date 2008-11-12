package MENTA::Base;
use strict;
use warnings;
use MENTA;
use MENTA::Controller::Base;

sub import {
    my $pkg = caller(0);
    strict->import;
    warnings->import;
    utf8->import;

    no strict 'refs';
    for my $meth (@MENTA::Controller::Base::METHODS) {
        *{"$pkg\::$meth"} =  *{"MENTA::Controller::Base::$meth"};
    }
    $MENTA::CONTROLLER = $pkg;
}

1;
