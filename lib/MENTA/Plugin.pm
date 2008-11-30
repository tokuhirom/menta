package MENTA::Plugin;
use strict;
use warnings;
use utf8;

sub import {
    my $pkg = caller(0);
    strict->import;
    warnings->import;
    utf8->import;

    no strict 'refs';
    for (qw/config data_dir/) {
        *{"${pkg}::$_"} = *{"MENTA::$_"}
    }
}

1;
