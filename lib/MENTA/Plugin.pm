package MENTA::Plugin;

sub import {
    my $pkg = caller(0);
    strict->import;
    warnings->import;
    utf8->import;

    for (qw/config data_dir/) {
        *{"${pkg}::$_"} = *{"main::$_"}
    }
}

1;
