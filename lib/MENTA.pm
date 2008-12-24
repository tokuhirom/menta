package MENTA;
use strict;
use warnings;
use utf8;
use CGI::ExceptionManager;
use MENTA::Dispatch ();
require 'Class/Accessor/Lite.pm';
require 'MENTA/Context.pm';
require 'Text/MicroTemplate.pm';

our $VERSION = '0.13';
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
        my ($class, $config, $req, $engine, $code) = @_;
        local $context = MENTA::Context->new(
            config   => $config,
            request  => $req,
            __engine => $engine,
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
}

# run as cgi
sub run_menta {
    my ($class, $config) = @_;
    $class->create_engine($config, 'MinimalCGI')->run;
}

sub create_engine {
    my ($class, $config, $interface) = @_;

    my $engine;
    $engine = HTTP::Engine->new(
        interface => {
            module => $interface,
            request_handler => sub {
                my $req = shift;
                local $MENTA::STASH;
                CGI::ExceptionManager->run(
                    callback => sub {
                        MENTA->run_context(
                            $config, $req, $engine, sub {
                                MENTA->call_trigger('BEFORE_DISPATCH');
                                MENTA::Dispatch->dispatch()
                            }
                        );
                    },
                    powered_by => '<strong>MENTA</strong>, Web Application Framework.',
                    stacktrace_class => 'HTTPEngine',
                    ($config->{menta}->{fatals_to_browser} ? () : (renderer => sub { "INTERNAL SERVER ERROR!" x 100 }))
                );
            }
        }
    );
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
    my $cachedir = config->{menta}->{cache_dir};
    return $cachedir if $cachedir;

    MENTA::Util::require_once('File/Spec.pm');
    return File::Spec->catfile(File::Spec->tmpdir(), "menta.${MENTA::VERSION}.$>.mt_cache");
}

sub base_dir {
    config->{menta}->{__processed_base_dir} ||= do {
        my $basedir = config->{menta}->{base_dir};
        unless ($basedir) {
            require Cwd;
            $basedir = Cwd::cwd();
        }
        $basedir =~ s!([^/])$!$1/!;
        $basedir;
    };
}

sub controller_dir {
    config->{menta}->{controller_dir} ||= base_dir() . 'app/controller/';
    config->{menta}->{controller_dir};
}

sub data_dir {
    config->{menta}->{data_dir} ||= base_dir() . 'app/data/';
    config->{menta}->{data_dir};
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
    CGI::ExceptionManager::detach($res);
}

sub render_and_print {
    my ($tmpl, @params) = @_;
    MENTA::Util::require_once('MENTA/TemplateLoader.pm');
    my $out = MENTA::TemplateLoader::__load($tmpl, @params);
    $out = MENTA::Util::encode_output($out);

    my $res = HTTP::Engine::Response->new(
        body => $out,
    );
    $res->headers->content_type("text/html; charset=" . MENTA::Util::_charset());
    _finish($res);
}

sub redirect {
    my ($location, ) = @_;

    my $res = HTTP::Engine::Response->new(
        status => 302,
    );
    $res->header('Location' => $location);
    _finish($res);
}

sub finalize {
    my $str = shift;
    my $content_type = shift || ('text/html; charset=' . MENTA::Util::_charset());

    my $res = HTTP::Engine::Response->new(
        status => 200,
        body   => $str,
    );
    $res->headers->content_type($content_type);
    _finish($res);
}

sub param        { MENTA::Util::decode_input(MENTA->context->request->param(@_)) }
sub upload       { MENTA->context->request->upload(@_) }
sub mobile_agent { MENTA->context->mobile_agent() }
sub current_url  {
    my $req = MENTA->context->request;
    my $protocol = 'http';
    my $port     = $ENV{SERVER_PORT} || 80;
    my $url = "http://" . $req->header('Host');
    $url .= docroot();
    $url .= "$ENV{PATH_INFO}";
    $url .= '?' . $ENV{QUERY_STRING};
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
    my $method = $ENV{REQUEST_METHOD};
    return $method eq 'POST';
}

sub docroot () { $ENV{SCRIPT_NAME} || '' }

sub uri_for {
    my ($path, $query) = @_;
    my @q;
    while (my ($key, $val) = each %$query) {
        $val = join '', map { /^[a-zA-Z0-9_.!~*'()-]$/ ? $_ : '%' . uc(unpack('H2', $_)) } split //, $val;
        push @q, "${key}=${val}";
    }
    docroot . '/' . $path . (scalar @q ? '?' . join('&', @q) : '');
}

sub static_file_path {
    my $path = shift;
    docroot . '/static/' . $path;
}

{
    package MENTA::Util;
    # ユーティリティメソッドたち。
    # これらのメソッドは一般ユーザーはよぶべきではない。

    # HTTP::MobileAgent::Plugin::Charset よりポート。
    # cp932 の方が実績があるので優先させる方針。
    # Shift_JIS とかじゃなくて cp932 にしとかないと、諸問題にひっかかりがちなので注意
    sub _mobile_encoding {
        MENTA->context->{encoding} ||= sub {
            my $ma = MENTA->context->mobile_agent();
            return 'utf-8' if $ma->is_non_mobile;
            return 'utf-8' if $ma->is_docomo && $ma->xhtml_compliant; # docomo の 3G 端末では UTF-8 の表示が保障されている
            return 'utf-8' if $ma->is_softbank && $ma->is_type_3gc;   # SoftBank 3G の一部端末は CP932 だと絵文字を送ってこない不具合がある
            return 'cp932';                                           # au は HTTPS のときに UTF-8 だと文字化ける場合がある
        }->();
    }

    # HTTP の入り口んとこで decode させる用
    sub decode_input {
        my ($txt, $fb) = @_;
        if (MENTA->context->config->{menta}->{support_mobile}) {
            require_once('Encode.pm');
            Encode::decode(_mobile_encoding(), $txt, $fb);
        } else {
            utf8::decode($txt);
            $txt;
        }
    }

    # 出力直前んとこで encode させる用
    sub encode_output {
        my ($txt, $fb) = @_;
        if (MENTA->context->config->{menta}->{support_mobile}) {
            require_once('Encode.pm');
            Encode::encode(_mobile_encoding(), $txt, $fb);
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
            return if $plugin_loaded->{$plugin};
            my $path = MENTA::base_dir() . "plugins/${plugin}.pl";
            require $path;
            $plugin_loaded->{$plugin}++;
            my $package = $__menta_extract_package->($path) || '';
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
