package MENTA::Util;
use strict;
use warnings;
use utf8;

sub import {
    my $pkg = caller(0);
    no strict 'refs';
    *{"$pkg\::read_file"}  = \&read_file;
    *{"$pkg\::write_file"} = \&write_file;
    *{"$pkg\::say"}        = \&say;
}

sub say { print @_, "\n" };

sub read_file {
    my $fname = shift;
    open my $fh, '<', $fname or die $!;
    my $s = do { local $/; join '', <$fh> };
    close $fh;
    $s;
}

sub write_file {
    my ($fname, $stuff) = @_;
    say "$fname を書き出します";
    open my $fh, '>', $fname or die $!;
    print $fh $stuff;
    close $fh;
}


1;
