package MENTA::TemplateLoader;
use strict;
use warnings;
use utf8;
use Carp ();

# originaly code from NanoA::TemplateLoader

sub __load {
    local $MENTA::TemplateLoader::Instance::render_context = {};
    __load_internal(@_);
}

sub __load_internal {
    my ($path, @params) = @_;
    if (__use_cache($path)) {
        my $tmplfname = MENTA::mt_cache_dir() . "/$path.c";

        open my $fh, '<', $tmplfname or die "テンプレートキャッシュを読み込めませんでした: ${tmplfname}($!)";
        my $tmplsrc = do { local $/; <$fh> };
        close $fh;

        local $@;
        my $tmplcode = eval $tmplsrc;
        die $@ if $@;
        return $tmplcode->(@params);
    } else {
        return __compile($path, @params);
    }
}

sub __compile {
    my ($path, @params) = @_;
    MENTA::Util::require_once('Text/MicroTemplate.pm');

    my $mt = Text::MicroTemplate->new(
        package_name => 'MENTA::TemplateLoader::Instance',
    );
    __build_file($mt, $path);
    my $code = __eval_builder($mt->code);
    my $compiled = do {
        local $SIG{__WARN__} = sub {
            print STDERR $mt->_error(shift, 4, $MENTA::TemplateLoader::Instance::render_context->{caller});
        };

        my $ret = eval $code;
        die "テンプレートコンパイルエラー\n$@" if $@;
        $ret;
    };
    my $out = $compiled->($mt, @params);
    __update_cache($path, $code);
    return $out;
}

sub __build_file {
    my ($mt, $file) = @_;
    my $path = MENTA::controller_dir();
    my $filepath = $path . '/' . $file;

    open my $fh, "<:utf8", $filepath
        or Carp::croak("テンプレートファイルがひらけません :$filepath:$!");
    my $src = do { local $/; <$fh> };
    close $fh;

    $mt->parse($src);
}

sub __eval_builder {
    my $code = shift;
    return <<"...";
package MENTA::TemplateLoader::Instance;
#line 1
sub {
    my \$_mt = shift;
    my \$out = Text::MicroTemplate::encoded_string((
        $code
    )->(\@_));
    if (my \$parent = delete \$MENTA::TemplateLoader::Instance::render_context->{extends}) {
        \$out = MENTA::TemplateLoader::__load_internal(\$parent);
    }
    \$out;
}
...
}

sub __update_cache {
    my ($path, $code) = @_;

    my $cache_path = MENTA::mt_cache_dir();
    foreach my $p (split '/', $path) {
        mkdir $cache_path;
        $cache_path .= "/$p";
    }
    $cache_path .= '.c';

    warn "WRITING $cache_path";
    open my $fh, '>:utf8', $cache_path
        or die "キャッシュファイルを作れません: $cache_path($!)";
    print $fh $code;
    close $fh;
}

sub __use_cache {
    my ($path) = @_;
    my $cache_dir = MENTA::mt_cache_dir();
    my @orig = stat MENTA::controller_dir() . "/$path"
        or return;
    my @cached = stat "$cache_dir/${path}.c"
        or return;
    return $orig[9] < $cached[9];
}

{
    package MENTA::TemplateLoader::Instance;
    no strict 'refs';
    for my $meth (qw/escape_html unescape_html raw_string config render param mobile_agent uri_for static_file_path docroot AUTOLOAD redirect current_url/) {
        *{__PACKAGE__ . '::' . $meth} = *{"MENTA::$meth"};
    }

    # following code is taken from Text::MicroTemplate::Extended by typester++.
    our $render_context;

    sub extends {
        $render_context->{extends} = $_[0];
    }

    sub block {
        my ($name, $code) = @_;

        my $block;
        if (defined $code) {
            $block = $render_context->{blocks}{$name} ||= {
                context_ref => $MENTA::TemplateLoader::Instance::_MTREF,
                code        => ref($code) eq 'CODE' ? $code : sub { return $code },
            };
        }
        else {
            $block = $render_context->{blocks}{$name}
                or die qq[block "$name" does not define];
        }

        if (!$render_context->{extends}) { # if base template.
            my $current_ref = $MENTA::TemplateLoader::Instance::_MTREF;
            my $block_ref   = $block->{context_ref};

            my $rendered = $$current_ref || '';
            $$block_ref = '';

            my $result = $block->{code}->() || $$block_ref || '';

            $$current_ref = $rendered . $result;
        }
    }
}

"ENDOFMODULE";
