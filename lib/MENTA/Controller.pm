package MENTA::Controller;
use strict;
use warnings;

sub import {
    my $pkg = caller(0);
    no strict 'refs';
    for my $meth (qw/escape_html unescape_html config render param mobile_agent uri_for static_file_path docroot AUTOLOAD redirect is_post_request render_and_print redirect finalize upload/) {
        *{"$pkg\::$meth"} = *{"MENTA::$meth"};
    }
}

1;
