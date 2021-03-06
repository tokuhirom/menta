package t::Utils;
use strict;
use warnings;
use lib 'lib';
use lib 'cgi-extlib-perl/extlib';
use MENTA;
use Plack::Util;
use Try::Tiny;

sub import {
    my $pkg = caller(0);
    strict->import;
    warnings->import;
    no strict 'refs';
    *{"$pkg\::run_cgi"} = \&run_cgi;
    *{"$pkg\::run_psgi"} = \&run_psgi;
}

sub run_cgi {
    my %env = @_;
    $env{CONTENT_LENGTH}  ||= 0;
    $env{PATH_INFO}       ||= '/';
    $env{QUERY_STRING}    ||= '';
    $env{HTTP_USER_AGENT} ||= 'test';
    $env{REQUEST_METHOD}  ||= 'GET';
    $env{SCRIPT_NAME}     ||= '/';
    $env{'psgi.input'}    ||= do {
        open my $fh, '<', \my $buf or die $!;
        $fh;
    };

    my $conf = {
        # MENTA 自体の設定
        menta => {
            # fatals_to_browser => 1,
            # 最大表示文字数
            max_post_body => 1_024_000,
            # モバイル対応
            support_mobile => 1,
            # MENTA そのものをおいているディレクトリ。CGI の場合は設定しなくてもよい。末尾のスラッシュを忘れずに。
            base_dir => './',
        },
        # あなたのアプリの設定
        application => {
            title => 'MENTA サンプルアプリ',
            sqlitefile => './app/data/data.sqlite',
            sql => {
                dsn => 'dbi:SQLite:./app/data/data.sqlite',
            },
            counter => {
                file => './app/data/counter.txt'
            },
        },
    };
    my $app = MENTA->create_app($conf);
    my $res = try {
        $app->(\%env);
    } catch {
        return [500, [], ["ERROR: $_"]];
    };
    my $out = '';
    $out .= "Status: $res->[0]\r\n";
    my $headers = $res->[1];
    while ( my ( $k, $v ) = splice( @$headers, 0, 2 ) ) {
        $out .= "$k: $v\n";
    }
    $out .= "\n";
    Plack::Util::foreach($res->[2], sub { $out .= $_[0] });
    return $out;
}

sub run_psgi {
    my %env = @_;
    $env{CONTENT_LENGTH}  ||= 0;
    $env{PATH_INFO}       ||= '/';
    $env{QUERY_STRING}    ||= '';
    $env{HTTP_USER_AGENT} ||= 'test';
    $env{REQUEST_METHOD}  ||= 'GET';
    $env{SCRIPT_NAME}     ||= '/';
    $env{'psgi.input'}    ||= do {
        open my $fh, '<', \my $buf or die $!;
        $fh;
    };

    my $conf = {
        # MENTA 自体の設定
        menta => {
            # fatals_to_browser => 1,
            # 最大表示文字数
            max_post_body => 1_024_000,
            # モバイル対応
            support_mobile => 1,
            # MENTA そのものをおいているディレクトリ。CGI の場合は設定しなくてもよい。末尾のスラッシュを忘れずに。
            base_dir => './',
        },
        # あなたのアプリの設定
        application => {
            title => 'MENTA サンプルアプリ',
            sqlitefile => './app/data/data.sqlite',
            sql => {
                dsn => 'dbi:SQLite:./app/data/data.sqlite',
            },
            counter => {
                file => './app/data/counter.txt'
            },
        },
    };
    my $app = MENTA->create_app($conf);
    my $res = try {
        $app->(\%env);
    } catch {
        return [500, [], ["ERROR: $_"]];
    };
    return $res;
}

1;
