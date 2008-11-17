package MENTA;
use strict;
use warnings;
use utf8;

our $REQ;
our $CONFIG;
our $REQUIRED;
our $MOBILEAGENTRE;
our $CARRIER;
our $STASH;
our $BUILT = 0;
BEGIN {
    $REQUIRED = {};

    {
        # copied from HTTP::MobileAgent
        my $DoCoMoRE = '^DoCoMo/\d\.\d[ /]';
        my $JPhoneRE = '^(?i:J-PHONE/\d\.\d)';
        my $VodafoneRE = '^Vodafone/\d\.\d';
        my $VodafoneMotRE = '^MOT-';
        my $SoftBankRE = '^SoftBank/\d\.\d';
        my $SoftBankCrawlerRE = '^Nokia[^/]+/\d\.\d';
        my $EZwebRE = '^(?:KDDI-[A-Z]+\d+[A-Z]? )?UP\.Browser\/';
        my $AirHRE = '^Mozilla/3\.0\((?:WILLCOM|DDIPOCKET)\;';
        $MOBILEAGENTRE = qr/(?:($DoCoMoRE)|($JPhoneRE|$VodafoneRE|$VodafoneMotRE|$SoftBankRE|$SoftBankCrawlerRE)|($EZwebRE)|($AirHRE))/;
    }
}

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
    local $MENTA::CARRIER;
    local $MENTA::STASH;

    {
        $config->{menta}->{max_post_body} ||= MENTA::DEFAULT_MAX_POST_BODY;
        $MENTA::CONFIG = $config;
    }

    local $SIG{__DIE__} = sub {
        my $msg = shift;
        warn $msg unless ref $msg;
        return $msg if ref $msg && ref $msg eq 'HASH' && $msg->{finished};
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
                        chomp $line;
                        ++$cur_line;
                        last if $cur_line > $end;
                        next if $cur_line < $start;
                        my @tag =
                            $cur_line == $linenum
                            ? ( '<strong>', '</strong>' )
                            : ( '', '' );
                        $code .= sprintf( "%s%5d: %s%s\n",
                            $tag[0], $cur_line,
                            escape_html($line),
                            $tag[1], );
                    }
                    close $file;
                    chomp $code;
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
            if (my $cdir = config->{menta}->{controller_dir}) {
                my $controller = "${cdir}/${path}.pl";
                if (-f $controller) {
                    package main;
                    do $controller;
                    if (my $e = $@) {
                        if (ref $e) {
                            die $e->{message};
                        } else {
                            die $e;
                        }
                    }
                    die $@ if $@;
                    if (my $code = main->can($meth)) {
                        $code->();
                        die "なにも出力してません";
                    } else {
                        die "「${mode}」というモードは存在しません!${controller} の中に ${meth} が定義されていないようです";
                    }
                } else {
                    my $tmplfname = ($MENTA::BUILT ? config->{menta}->{tmpl_cache_dir} : config->{menta}->{tmpl_dir}) . "/${mode}.html";
                    if (-f $tmplfname) {
                        render("${mode}.html");
                    } else {
                        die "「${mode}」というモードは存在しません。別コントローラファイルもありません(${controller})。テンプレートファイルもありません(${tmplfname})";
                    }
                }
            } else {
                die "「${mode}」というモードは存在しません。別コントローラ用ディレクトリは設定されていません";
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
            die "${path} を処理する方法がわかりません";
        }
    };
    if (my $err = $@) {
        die "エラー処理失敗: ${err}" unless ref $err eq 'HASH';
        return if $err->{finished};

        warn $err->{message};

        print "Status: 500\r\n";
        print "Content-type: text/html; charset=utf-8\r\n";
        print "\r\n";

        my $body = do {
            if ($config->{menta}->{kcatch_mode}) {
                my $msg = escape_html($err->{message});
                chomp $msg;
                my $out = qq{<!doctype html><head><title>500 Internal Server Error</title><style type="text/css">body { margin: 0; padding: 0; background: rgb(230, 230, 230); color: rgb(44, 44, 44); } h1 { margin: 0 0 .5em; padding: .25em .5em .1em 1.5em; border-bottom: thick solid rgb(0, 0, 15); background: rgb(63, 63, 63); color: rgb(239, 239, 239); font-size: x-large; } p { margin: .5em 1em; } li { font-size: small; } pre { background: rgb(255, 239, 239); color: rgb(47, 47, 47); font-size: medium; } pre code strong { color: rgb(0, 0, 0); background: rgb(255, 143, 143); } p.f { text-align: right; font-size: xx-small; } p.f span { font-size: medium; }</style></head><h1>500 Internal Server Error</h1><p>${msg}</p><ol>};
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
    s/&#39;/'/g;
    s/&amp;/&/g;
    return $_;
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
    my $conf = config()->{menta};
    my $tmpldir = $conf->{tmpl_dir} or die "[menta] セクションに tmpl_dir が設定されていません";
    my $cachedir = $conf->{tmpl_cache_dir} or die "[menta] セクションに tmpl_cache_dir が設定されていません";
    mkdir $cachedir unless $MENTA::BUILT || -d $cachedir;
    my $cachefname = "$cachedir/$tmpl";
    my $tmplfname = "$tmpldir/$tmpl";
    my $use_cache = $MENTA::BUILT || sub {
        my @orig = stat $tmplfname or return 1;
        my @cached = stat $cachefname or return;
        return $orig[9] < $cached[9];
    }->();
    my $out;
    if ($use_cache) {
        my $tmplcode = do $cachefname;
        die $@ if $@;
        die "テンプレートキャッシュを読み込めませんでした: ${tmplfname}" unless $tmplcode;
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
        write_file($cachefname, "package main; use utf8;\n${src}");
    }
    $out;
}

sub detach() {
    die {finished => 1};
}

sub render {
    my ($tmpl, @params) = @_;
    my $out = render_partial($tmpl, @params);
    utf8::encode($out);
    print "Content-Type: text/html; charset=utf-8\r\n";
    print "\r\n";
    print $out;

    detach;
}

sub redirect {
    my ($location, ) = @_;
    print "Status: 302\r\n";
    print "Location: $location\r\n";
    print "\r\n";

    detach;
}

sub finalize {
    my $str = shift;
    my $content_type = shift || 'text/html; charset=utf-8';

    print "Content-Type: $content_type\r\n";
    print "\r\n";
    print $str;

    detach;
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

sub parse_multipart {
    my ($data, $boundary) = @_;

    my @lines = split(/\n/, $data);
    my ($val, $key, $step) = ('', '', 0);
    for my $line (@lines) {
        my $sline = $line;
        $sline =~ s![\r\n]+!!msg;
        if ($boundary eq $sline) {
            if($step eq 2 && $key ne '') {
                chop($val);
                $MENTA::REQ->{$key} = $val;
            }
            $step = 1;
            $key = '';
            $val = '';
        } elsif ("${boundary}--" eq $sline) {
            if ($step eq 2 && $key ne '') {
                chop($val);
                $MENTA::REQ->{$key} = $val;
            }
            return 1;
        } elsif ($step eq 2) {
            $val .= "\n" if $val;
            $val .= $line;
        } elsif ($sline =~ /^(?i:Content-Disposition): *form-data; *name="((?:\\"|[^"])*)/ && $step eq 1) {
            $key = $1;
        } elsif ($sline eq '' && $step eq 1) {
            $step = 2;
        }
    }
    return 1;
}

sub param {
    my $key = shift;

    unless (defined $MENTA::REQ) {
        my $input;
        if ($ENV{'REQUEST_METHOD'} eq 'POST') {
            my $max_post_body = config()->{menta}->{max_post_body};
            if ($max_post_body > 0 && $ENV{CONTENT_LENGTH} > $max_post_body) {
                die "投稿データが長すぎです";
            } else {
                read(STDIN, $input, $ENV{'CONTENT_LENGTH'});
            }
        } else {
            $input = $ENV{QUERY_STRING};
        }

        my $type = $ENV{'CONTENT_TYPE'};
        if ($type && $type =~ m{^multipart/form-data; *boundary=}) {
            parse_multipart $input, '--'.substr($type, 30);
        } else {
            for (split /[&;]+/, $input) {
                my ($key, $val) = split /=/, $_;
                if ($val) {
                    $val =~ tr/+/ /;
                    $val =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack('H2', $1)/eg;
                    utf8::decode($val);
                }
                $MENTA::REQ->{$key} = $val;
            }
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

# これが返す文字は HTTP::MobileAgent と互換性がある
sub mobile_carrier () {
    if ($MENTA::CARRIER) { return $MENTA::CARRIER }

    my $ua = $ENV{HTTP_USER_AGENT} || '';
    my $ret = 'N';
    if ($ua =~ /$MENTA::MOBILEAGENTRE/) {
        $ret = $1 ? 'I' : $2 ? 'V' : $3 ? 'E' : 'H';
    }
    $MENTA::CARRIER = $ret;
    $ret;
}

sub mobile_carrier_longname {
    {
        N => 'NonMobile',
        I => 'DoCoMo',
        E => 'EZweb',
        V => 'Softbank',
        H => 'AirH',
    }->{ mobile_carrier() }
}

sub load_plugin {
    my $plugin = shift;
    require_once($MENTA::BUILT ? "plugins/${plugin}.pl" : "../plugins/${plugin}.pl");
}

sub is_post_request () {
    my $method = $ENV{REQUEST_METHOD};
    return $method eq 'POST';
}

# TODO: CGI にはこのための環境変数ってなかったっけ?
sub docroot () {
    config()->{application}->{docroot}
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

1;
