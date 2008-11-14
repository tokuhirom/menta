package MENTA;
use strict;
use warnings;
use utf8;

our $FINISHED;
our $REQ;
our $CONFIG;
our $REQUIRED;
BEGIN { $REQUIRED = {} }

sub import {
    strict->import;
    warnings->import;
    utf8->import;
}

sub DEFAULT_MAX_POST_BODY () { 1_024_000 }

package main;

sub config () { $MENTA::CONFIG }

sub run_menta {
    my $config = shift @_;

    local $MENTA::CONFIG;
    local $MENTA::REQ;
    local $MENTA::FINISHED = 0;

    {
        $config->{menta}->{max_post_body} ||= MENTA::DEFAULT_MAX_POST_BODY;
        $MENTA::CONFIG = $config;
    }

    local $SIG{__DIE__} = sub {
        my $msg = shift;
        my $i = 0;
        my @trace;
        while ( my ($package, $filename, $line,) = caller($i) ) {
            last if $filename eq 'bin/cgi-server.pl';
            my $context = sub {
                my ( $file, $linenum ) = @_;
                my $code;
                if ( -f $file ) {
                    my $start = $linenum - 3;
                    my $end   = $linenum + 3;
                    $start = $start < 1 ? 1 : $start;
                    open my $fh, '<:utf8', $file or die "エラー画面表示用に ${file} を開こうとしたのに開けません: $!";
                    my $cur_line = 0;
                    while ( my $line = <$fh> ) {
                        ++$cur_line;
                        last if $cur_line > $end;
                        next if $cur_line < $start;
                        my @tag =
                            $cur_line == $linenum
                            ? (q{<strong>}, '</strong>')
                            : ( '', '' );
                        $code .= sprintf( '%s%5d: %s%s',
                            $tag[0], $cur_line,
                            escape_html($line),
                            $tag[1], );
                    }
                    close $file;
                }
                return $code;
            }->($filename, $line);
            push @trace, +{ level => $i, package => $package, filename => $filename, line => $line, context => $context };
            $i++;
        }
        die { message => $msg, trace => \@trace };
    };

    eval {
        my $path = $ENV{PATH_INFO} || '/';
        $path =~ s!^/+!!g;
        if ($path =~ /^[a-z0-9_]*$/) {
            my $mode = $path || 'index';
            my $meth = "do_$mode";
            if (my $code = main->can($meth)) {
                $code->();
                unless ($MENTA::FINISHED) {
                    die "なにも出力してません";
                }
            } else {
                if (my $cdir = config->{menta}->{controller_dir}) {
                    my $controller = "${cdir}/${path}.pl";
                    if (-f $controller) {
                        package main;
                        do $controller;
                        die $@ if $@;
                        if (my $code = main->can($meth)) {
                            $code->();
                            unless ($MENTA::FINISHED) {
                                die "なにも出力してません";
                            }
                        } else {
                            die "「${mode}」というモードは存在しません!${controller} の中に ${meth} が定義されていないようです";
                        }
                    } else {
                        die "「${mode}」というモードは存在しません。別コントローラファイルもありません(${controller})";
                    }
                } else {
                    die "「${mode}」というモードは存在しません。別コントローラ用ディレクトリは設定されていません";
                }
            }
        } elsif ($path ne 'menta.cgi' && -f $path) {
            if (open my $fh, '<', $path) {
                printf "Content-Type: %s\r\n\r\n", guess_mime_type($path);
                print do { local $/; <$fh> };
                close $fh;
            } else {
                die "ファイルが開きません";
            }
        } elsif ($path =~ /^(?:crossdomain\.xml|favicon\.ico|robots\.txt)$/) {
            print "status: 404\r\ncontent-type: text/plain\r\n\r\n";
        } else {
            die "$path を処理する方法がわかりません";
        }
    };
    if (my $err = $@) {
        die "エラー処理失敗: $err" unless ref $err eq 'HASH';

        warn $err->{message};

        print "Status: 500\r\n";
        print "Content-type: text/html; charset=utf-8\r\n";
        print "\r\n";

        my $body = do {
            if ($config->{menta}->{kcatch_mode}) {
                my $msg = escape_html($err->{message});
                my $out = qq{<!doctype html><head><title>500 Internal Server Error</title><style type="text/css">body { margin: 0; padding: 0; background: rgb(230, 230, 230); color: rgb(44, 44, 44); } h1 { margin: 0 0 .5em; padding: .25em; border: 0 none; border-bottom: medium solid rgb(0, 0, 15); background: rgb(63, 63, 63); color: rgb(239, 239, 239); font-size: x-large; } p { margin: .5em 1em; } li { font-size: small; } pre { background: rgb(255, 239, 239); color: rgb(47, 47, 47); font-size: medium; } pre code strong { color: rgb(0, 0, 0); background: rgb(255, 143, 143); } p.f { text-align: right; font-size: xx-small; } p.f span { font-size: medium; }</style></head><h1>500 Internal Server Error</h1><p>$msg</p><ol>};
                for my $stack (@{$err->{trace}}) {
                    $out .= '<li>' . escape_html(join(', ', $stack->{package}, $stack->{filename}, $stack->{line}))
                         . qq(<pre><code>$stack->{context}</code></pre></li>);
                }
                $out .= qq{</ol><p class="f"><span>Powered by <strong>MENTA</strong></span>, Web application framework</p>};
                $out;
            } else {
                qq{<html><body><p style="color: red">500 Internal Server Error</p></body></html>\n};
            }
        };
        utf8::encode($body);
        print $body;
    }
}

sub escape_html {
    my $str = shift;
    $str =~ s/&/&amp;/g;
    $str =~ s/>/&gt;/g;
    $str =~ s/</&lt;/g;
    $str =~ s/"/&quot;/g;
    $str =~ s/'/&#39;/g;
    return $str;
}

sub guess_mime_type {
    my $ext = shift;
    $ext =~ s/.+\.(.+)$/$1/;

    # TODO should be moved to other.
    my $mime_map = {
        css => 'text/css',
        js  => 'application/javascript',
        txt => 'text/plain',
    };
    $mime_map->{$ext} || 'application/octet-stream';
}

# TODO: ディレクトリトラバーサル対策
sub render_partial {
    my ($tmpl, @params) = @_;
    my $tmpldir = config()->{menta}->{tmpl_dir} or die "[menta] セクションに tmpl_dir が設定されていません";
    my $cachedir = config()->{menta}->{tmpl_cache_dir} or die "[menta] セクションに tmpl_cache_dir が設定されていません";
    mkdir $cachedir unless -d $cachedir;
    my $cachefname = "$cachedir/$tmpl";
    my $tmplfname = "$tmpldir/$tmpl";
    my $use_cache = sub {
        my @orig = stat $tmplfname or return 1;
        my @cached = stat $cachefname or return;
        return $orig[9] < $cached[9];
    }->();
    my $out;
    if ($use_cache) {
        my $tmplcode = do $cachefname;
        die $@ if $@;
        $out = $tmplcode->(@params);
    } else {
        die "「${tmplfname}」という名前のテンプレートファイルは見つかりません" unless -f $tmplfname;
        require_once('MENTA/Template.pm');
        my $tmplsrc = read_file($tmplfname);
        my $mt = MENTA::Template->new;
        $mt->parse($tmplsrc);
        $mt->build();
        my $src = $mt->code();
        my $tmplcode = eval $src;
        die $@ if $@;
        $out = $tmplcode->(@params);
        write_file($cachefname, "package main; use utf8;\n$src");
    }
    $out;
}

sub render {
    my ($tmpl, @params) = @_;
    my $out = render_partial($tmpl, @params);
    utf8::encode($out);
    print "Content-Type: text/html; charset=utf-8\r\n";
    print "\r\n";
    print $out;

    $MENTA::FINISHED++;
}

sub redirect {
    my ($location, ) = @_;
    print "Status: 302\r\n";
    print "Location: $location\r\n";
    print "\r\n";

    $MENTA::FINISHED++;
}

sub finalize {
    my $str = shift;
    my $content_type = shift || 'text/html; charset=utf-8';

    print "Content-Type: $content_type\r\n";
    print "\r\n";
    print $str;

    $MENTA::FINISHED++;
}

sub read_file {
    my $fname = shift;
    open my $fh, '<:utf8', $fname or die "${fname} を読み込み用に開けません: $!";
    my $s = do { local $/; join '', <$fh> };
    close $fh;
    $s;
}

sub write_file {
    my ($fname, $stuff) = @_;
    open my $fh, '>:utf8', $fname or die "${fname} を書き込み用に開けません: $!";
    print $fh $stuff;
    close $fh;
}

sub param {
    my $key = shift;

    unless (defined $MENTA::REQ) {
        my $input;
        if ($ENV{'REQUEST_METHOD'} eq "POST") {
            my $max_post_body = config()->{menta}->{max_post_body};
            if ($max_post_body > 0 && $ENV{CONTENT_LENGTH} > $max_post_body) {
                die "投稿データが長すぎです";
            } else {
                read(STDIN, $input, $ENV{'CONTENT_LENGTH'});
            }
        } else {
            $input = $ENV{QUERY_STRING};
        }

        for (split /[&;]+/, $input) {
            my ($key, $val) = split /=/, $_;
            if ($val) {
                $val =~ tr/+/ /;
                $val =~ s/%([a-fA-F0-9]{2})/pack("H2", $1)/eg;
                utf8::decode($val);
            }
            $MENTA::REQ->{$key} = $val;
        }
    }

    return $MENTA::REQ->{$key};
}

sub require_once {
    my $path = shift;
    return if $MENTA::REQUIRED->{$path};
    require $path;
    $MENTA::REQUIRED->{$path} = 1;
}

1;
