package MENTA;
use strict;
use warnings;
use utf8;
use CGI::ExceptionManager;
use MENTA::Dispatch ();
use CGI::Simple;
use Class::Trigger qw/BEFORE_OUTPUT/;
require 'Class/Accessor/Lite.pm';
require 'MENTA/Context.pm';

our $VERSION = '0.07';
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
        my ($class, $config, $code) = @_;
        local $context = MENTA::Context->new(
            config => $config,
        );
        $code->();
    }
}

package main; # ここ以下の関数はすべてコントローラで呼ぶことができます


sub config () { MENTA->context->config }

sub run_menta {
    my $config = shift @_;

    CGI::ExceptionManager->run(
        callback => sub {
            MENTA->run_context(
                $config => sub {
                    MENTA::Dispatch->dispatch()
                }
            );
        },
        powered_by => '<strong>MENTA</strong>, Web Application Framework.',
        ($config->{menta}->{fatals_to_browser} ? () : (renderer => sub { "INTERNAL SERVER ERROR!" x 100 }))
    );
}

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

sub mt_cache_dir {
    # $> は $EFFECTIVE_USER_ID です。詳しくは perldoc perlvar を参照。
    config->{menta}->{cache_dir} || "/tmp/menta.${MENTA::VERSION}.$>.mt_cache"
}

sub controller_dir {
    config->{menta}->{controller_dir} || 'app/controller/'
}

sub data_dir {
    config->{menta}->{data_dir} || 'app/data/'
}

sub __render_partial {
    my ($tmpl, $tmpldir, @params) = @_;
    MENTA::TemplateLoader::__load("$tmpldir/$tmpl", @params);
}

# テンプレートの一部を描画する
sub render {
    my ($tmpl, @params) = @_;
    my $out = MENTA::TemplateLoader::__load("@{[ controller_dir() ]}/$tmpl", @params);
    bless \$out, 'MENTA::Template::RawString';
}

sub _finish {
    MENTA->call_trigger('BEFORE_OUTPUT');

    my $res = MENTA->context->res;
    $res->headers->content_length(length($res->content));
    print $res->as_string;
    CGI::ExceptionManager::detach();
}

sub render_and_print {
    my ($tmpl, @params) = @_;
    MENTA::Util::require_once('MENTA/TemplateLoader.pm');
    my $out = MENTA::TemplateLoader::__load("@{[ controller_dir() ]}/$tmpl", @params);
    $out = MENTA::Util::encode_output($out);

    my $res = MENTA->context->res;
    $res->headers->content_type("text/html; charset=" . MENTA::Util::_charset());
    $res->content($out);

    _finish();
}

sub redirect {
    my ($location, ) = @_;

    my $res = MENTA->context->res;
    $res->header('Status' => 302);
    $res->header('Location' => $location);

    _finish();
}

sub finalize {
    my $str = shift;
    my $content_type = shift || ('text/html; charset=' . MENTA::Util::_charset());

    my $res = MENTA->context->res;
    $res->headers->content_type($content_type);
    $res->content($str);

    _finish();
}

sub param        { MENTA->context->request->param(@_) }
sub upload       { MENTA->context->request->upload(@_) }
sub mobile_agent { MENTA->context->mobile_agent() }


{
    # プラグインのロード機構

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
    my $_load_plugin = sub {
        my $plugin = shift;
        return if $plugin_loaded->{$plugin};
        my $path = "plugins/${plugin}.pl";
        require $path;
        $plugin_loaded->{$plugin}++;
        my $package = $__menta_extract_package->($path) || '';
        no strict 'refs';
        for (
            grep { /$plugin/ }
            grep { defined &{"${package}::$_"} }
            keys %{"${package}::"}
        ) {
            *{"main::$_"} = *{"${package}::$_"}
        }
    };

    sub AUTOLOAD {
        my $method = our $AUTOLOAD;
        $method =~ s/.*:://o;
        (my $prefix = $method) =~ s/_.+//;
        die "変な関数よびだしてませんか？: $method" unless $prefix;
        $_load_plugin->($prefix);
        return main->can($method)->(@_);
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
}

1;
