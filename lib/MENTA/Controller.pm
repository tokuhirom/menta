package MENTA::Controller;
use strict;
use warnings;
use Filter::Util::Call ();

sub import {
    my $controller_dir = MENTA::controller_dir();

    Filter::Util::Call::filter_add(sub {
        my $status;
        my $data = '';
        my $count = 0;
        while ($status = Filter::Util::Call::filter_read()) {
            return $status if $status < 0;
            $data .= $_;
            $count++;
            $_ = "";
        }
        return $count if not $count;

        my $pkg = do {
            local $_ = (caller(0))[1];
            s{^$controller_dir/*|\.pl$}{}g;
            s{/}{::};
            "MENTA::Controller::$_";
        };

        $_ = qq{use strict;use warnings;\npackage $pkg;\nMENTA::Controller->install_functions();\n$data;"$pkg";};

        return $count;
    });
}

sub install_functions {
    my $pkg = caller(0);
    no strict 'refs';
    for my $meth (qw/escape_html unescape_html raw_string config render param mobile_agent uri_for static_file_path docroot AUTOLOAD redirect is_post_request render_and_print redirect finalize upload current_url/) {
        *{"$pkg\::$meth"} = *{"MENTA::$meth"};
    }
}

1;
