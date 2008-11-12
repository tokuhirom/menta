package MENTA::Injector;
use strict;
use warnings;

sub inject {
    no strict 'refs';
    for my $meth (qw/render redirect/) {
        *{"main\::$meth"} = *{"MENTA::Controller::Base::$meth"};
    }
    for my $meth (qw/config/) {
        *{"main::$meth"} = *{"MENTA::$meth"};
    }
}

1;
