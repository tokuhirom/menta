package MENTA;
use strict;
use warnings;
use utf8;

our $FINISHED;
our $REQ;
our $CONFIG;

sub import {
    strict->import;
    warnings->import;
    utf8->import;
}

sub DEFAULT_MAX_POST_BODY () { 1_024_000 }

package main;

sub config { $MENTA::CONFIG }

sub run_menta {
    my $config = shift @_;

    local $MENTA::CONFIG;
    local $MENTA::REQ;
    local $MENTA::FINISHED = 0;

    {
        $config->{menta}->{max_post_body} ||= MENTA::DEFAULT_MAX_POST_BODY;
        $MENTA::CONFIG = $config;
    }

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
                die "「${mode}」というモードは存在しません";
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
        # TODO: 美麗な画面を出す
        warn $err;

        print "Status: 500\r\n";
        print "Content-type: text/html; charset=utf-8\r\n";
        print "\r\n";

        my $body = do {
            if ($config->{menta}->{kcatch_mode}) {
                $err = escape_html($err);
                qq{<!doctype html><title>INTERNAL SERVER ERROR!!! HACKED BY MENTA</title><body style="background: red; color: white; font-weight: bold"><marquee behavior="alternate" scrolldelay="66" style="text-transform: uppercase"><span style="font-size: xx-large; color: black">&#x2620;</span> <span style="color: green">500</span> Internal Server Error <span style="font-size: xx-large; color: black">&#x2620;</span></marquee><p><span style="color: blue">$err</span></p><p style="text-align: right; color: black"><strong>Regards,<br>MENTA</strong></p>\n};
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
sub render {
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
        require MENTA::Template;
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

        for ( split /&/, $input) {
            my ($key, $val) = split /=/, $_;
            if ($val) {
                $val =~ tr/+/ /;
                $val =~ s/%([a-fA-F0-9]{2})/pack("H2", $1)/eg;
            }
            $MENTA::REQ->{$key} = $val;
        }
    }

    return $MENTA::REQ->{$key};
}

1;
