package MENTA;
use strict;
use warnings;
use utf8;
use MENTA::Dispatch ();
use Try::Tiny;
require 'MENTA/Request.pm';
require 'Class/Accessor/Lite.pm';
require 'MENTA/Context.pm';
require 'MENTA/MobileAgent.pm';
require 'Text/MicroTemplate.pm';

our $VERSION = '0.15';
our $REQ;
our $CONFIG;
our $STASH;

sub import {
    strict->import;
    warnings->import;
    utf8->import;
}

{
    our $context;
    sub context { $context }
    sub run_context {
        my ($class, $config, $req, $code) = @_;
        local $context = MENTA::Context->new(
            config   => $config,
            request  => $req,
        );
        $code->();
    }
}

{
    # Class::Trigger はロードに時間かかるので自前で実装してる
    my $static_triggers;
    sub call_trigger {
        my ($class, $triggername, @args) = @_;
        my $c = context();
        for my $code (@{$c->{triggers}->{$triggername}}, @{ $static_triggers->{triggers}->{$triggername} || [] }) {
            $code->($c, @args);
        }
    }

    sub add_trigger {
        my ($class, $triggername, $code) = @_;
        if (ref context()) {
            push @{context()->{triggers}->{$triggername}}, $code;
        } else {
            push @{$static_triggers->{triggers}->{$triggername}}, $code;
        }
    }
    sub add_trigger_static {
        my ($class, $triggername, $code) = @_;
        push @{$static_triggers->{triggers}->{$triggername}}, $code;
    }
}

# run as cgi
sub run_menta {
    my ($class, $config) = @_;
    require 'Plack/Server/CGI.pm';
    my $app = $class->create_app($config);
    Plack::Server::CGI->new->run($app);
}

sub create_app {
    my ($class, $config) = @_;
    my $app = sub {
        my $env = shift;
        local $MENTA::STASH;
        try {
            my $req = MENTA::Request->new($env);
            MENTA->run_context(
                $config, $req, sub {
                    MENTA->call_trigger('BEFORE_DISPATCH');
                    MENTA::Dispatch->dispatch($env)
                }
            );
        } catch {
            if ($_ && ref $_ eq 'ARRAY') {
                return $_;
            } else {
                die $_;
            }
        };
    };
    if ($config->{menta}->{fatals_to_browser}) {
        my $origapp = $app;
        $app = sub {
            my @args = @_;
            my $res;
            try {
                local $SIG{__DIE__} = sub {
                    if (ref $@ && ref $@ eq 'ARRAY') {
                        $res = $@;
                    } else {
                        require 'Devel/StackTrace.pm';
                        require 'Devel/StackTrace/AsHTML.pm';
                        $res = [
                            500,
                            [ 'Content-Type' => 'text/html; charset=utf-8' ],
                            [MENTA::Util::encode_output(Devel::StackTrace->new->as_html)]
                        ];
                    }
                    die @_;
                };
                $origapp->(@args);
            };
            return $res;
        };
    }
    return $app;
}

sub config () { MENTA->context->config }

sub escape_html {
    local $_ = shift;
    return $_ unless $_;
    s/&/&amp;/g;
    s/>/&gt;/g;
    s/</&lt;/g;
    s/"/&quot;/g;
    s/'/&#39;/g;
    return $_;
}

sub unescape_html {
    local $_ = shift;
    return $_ unless $_;
    s/&gt;/>/g;
    s/&lt;/</g;
    s/&quot;/"/g;
    s/&#0*39;/'/g;
    s/&amp;/&/g;
    return $_;
}

sub raw_string {
    my $s = shift;
    ref $s eq 'Text::MicroTemplate::EncodedString'
        ? $s
            : bless \$s, 'Text::MicroTemplate::EncodedString';
}

sub mt_cache_dir {
    # $> は $EFFECTIVE_USER_ID です。詳しくは perldoc perlvar を参照。
    my $cachedir = MENTA->context->config->{menta}->{cache_dir};
    return $cachedir if $cachedir;

    my $tmpdir = do {
        if (-d '/tmp/') {
            '/tmp/';
        } else {
            MENTA::Util::require_once('File/Spec.pm');
            File::Spec->tmpdir()
        }
    };
    return "$tmpdir/menta.${MENTA::VERSION}.$>.mt_cache";
}

sub base_dir {
    MENTA->context->config->{menta}->{__processed_base_dir} ||= do {
        my $basedir = MENTA->context->config->{menta}->{base_dir};
        unless ($basedir) {
            require Cwd;
            $basedir = Cwd::cwd();
        }
        $basedir =~ s!([^/])$!$1/!;
        $basedir;
    };
}

sub controller_dir {
    MENTA->context->config->{menta}->{controller_dir} ||= base_dir() . 'app/controller/';
    MENTA->context->config->{menta}->{controller_dir};
}

sub data_dir {
    MENTA->context->config->{menta}->{data_dir} ||= base_dir() . 'app/data/';
    MENTA->context->config->{menta}->{data_dir};
}

sub __render_partial {
    my ($tmpl, $tmpldir, @params) = @_;
    MENTA::TemplateLoader::__load($tmpl, @params);
}

# テンプレートの一部を描画する
sub render {
    my ($tmpl, @params) = @_;
    my $out = MENTA::TemplateLoader::__load($tmpl, @params);
    bless \$out, 'Text::MicroTemplate::EncodedString';
}

sub _finish {
    my $res = shift;
    MENTA->call_trigger('BEFORE_OUTPUT', $res);
    die $res;
}

sub render_and_print {
    my ($tmpl, @params) = @_;
    MENTA::Util::require_once('MENTA/TemplateLoader.pm');
    my $out = MENTA::TemplateLoader::__load($tmpl, @params);
    $out = MENTA::Util::encode_output($out);

    _finish([
        200, [
            'Content-Type' => "text/html; charset=" . MENTA::Util::_charset()
        ], [$out]
    ]);
}

sub redirect {
    my ($location, ) = @_;
    Carp::confess("missing location for redirect") unless defined $location;

    _finish([302, ['Location' => $location], []]);
}

sub finalize {
    my $str = shift;
    my $content_type = shift || ('text/html; charset=' . MENTA::Util::_charset());

    _finish([200, ['Content-Type' => $content_type], [$str]]);
}

sub param {
    if (wantarray) {
        map { MENTA::Util::decode_input($_) } MENTA->context->request->param(@_);
    }
    else {
        MENTA::Util::decode_input(MENTA->context->request->param(@_));
    }
}
sub upload       { MENTA->context->request->upload(@_) }
sub mobile_agent { MENTA->context->mobile_agent() }
sub current_url  {
    my $req = MENTA->context->request;
    my $env = $req->{env};
    my $protocol = 'http';
    my $port     = $env->{SERVER_PORT} || 80;
    my $url = "http://" . $req->header('Host');
    $url .= docroot();
    $url .= "$env->{PATH_INFO}";
    $url .= '?' . $env->{QUERY_STRING};
}

{
    # プラグインの自動ロード機構
    sub AUTOLOAD {
        my $method = our $AUTOLOAD;
        $method =~ s/.*:://o;
        (my $prefix = $method) =~ s/_.+//;
        die "変な関数よびだしてませんか？: $method" unless $prefix;
        MENTA::Util::load_plugin($prefix);
        my $code = MENTA->can($method);
        die "${method} という関数が見つかりません" unless $code;
        return $code->(@_);
    }
}

sub is_post_request () {
    my $env = MENTA->context->request->{env};
    my $method = $env->{REQUEST_METHOD};
    return $method eq 'POST';
}

sub docroot () {
    my $env = MENTA->context->request->{env};
    $env->{SCRIPT_NAME} || '/'
}

sub uri_for {
    my ($path, $query) = @_;
    my @q;
    while (my ($key, $val) = each %$query) {
        $val = join '', map { /^[a-zA-Z0-9_.!~*'()-]$/ ? $_ : '%' . uc(unpack('H2', $_)) } split //, $val;
        push @q, "${key}=${val}";
    }
    docroot . $path . (scalar @q ? '?' . join('&', @q) : '');
}

sub static_file_path {
    my $path = shift;
    docroot . 'static/' . $path;
}

{
    package MENTA::Util;
    # ユーティリティメソッドたち。
    # これらのメソッドは一般ユーザーはよぶべきではない。
    sub _mobile_encoding {
        MENTA->context->{encoding} ||= do {
            my $ua = MENTA->context->request->{env}->{HTTP_USER_AGENT};
            MENTA::MobileAgent->detect_charset($ua);
        };
    }

    # HTTP の入り口んとこで decode させる用
    sub decode_input {
        my ($txt, $fb) = @_;
        if (MENTA->context->config->{menta}->{support_mobile}) {
            my $encoding = _mobile_encoding();
            if ($encoding eq 'utf-8') {
                utf8::decode($txt);
                $txt;
            } else {
                require_once('Encode.pm');
                Encode::decode($encoding, $txt, $fb);
            }
        } else {
            utf8::decode($txt);
            $txt;
        }
    }

    # 出力直前んとこで encode させる用
    sub encode_output {
        my ($txt, $fb) = @_;
        if (MENTA->context->config->{menta}->{support_mobile}) {
            my $encoding = _mobile_encoding();
            if ($encoding eq 'utf-8') {
                utf8::encode($txt);
                $txt;
            } else {
                require_once('Encode.pm');
                Encode::encode($encoding, $txt, $fb);
            }
        } else {
            utf8::encode($txt);
            $txt;
        }
    }

    # charset に設定する文字列を生成
    sub _charset {
        if (MENTA->context->config->{menta}->{support_mobile}) {
            +{ 'utf-8' => 'UTF-8', cp932 => 'Shift_JIS' }->{_mobile_encoding()};
        } else {
            'UTF-8';
        }
    }

    # 一回ロードしたクラスは二度ロードしないための仕組み。
    {
        my $required = {};
        sub require_once {
            my $path = shift;
            return if $required->{$path};
            require $path;
            $required->{$path} = 1;
        }
    }

    {
        my $plugin_loaded;
        my $__menta_extract_package = sub {
            my $modulefile = shift;
            open my $fh, '<', $modulefile or die "$modulefile を開けません: $!";
            my $in_pod = 0;
            while (<$fh>) {
                $in_pod = 1 if m/^=\w/;
                $in_pod = 0 if /^=cut/;
                next if ( $in_pod || /^=cut/ );    # skip pod text
                next if /^\s*\#/;

                /^\s*package\s+(.*?)\s*;/ and return $1;
            }
            return;
        };
        sub load_plugin {
            my $plugin = shift;
            return $plugin_loaded->{$plugin} if $plugin_loaded->{$plugin};
            my $path = MENTA::base_dir() . "plugins/${plugin}.pl";
            require $path;
            my $package = $__menta_extract_package->($path) || '';
            $plugin_loaded->{$plugin} = $package;
            die "${plugin} プラグインの中にパッケージ宣言がみつかりません" unless $package;
            no strict 'refs';
            for (
                grep { /$plugin/ }
                grep { defined &{"${package}::$_"} }
                keys %{"${package}::"}
            ) {
                *{"MENTA::$_"} = *{"${package}::$_"}
            }
            return $package;
        }
    }
}

1;
