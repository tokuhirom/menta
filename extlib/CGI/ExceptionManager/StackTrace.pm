package CGI::ExceptionManager::StackTrace;
use strict;
use warnings;

# from MENTA and NanoA

sub _escape_html {
    my $str = shift;
    $str =~ s/&/&amp;/g;
    $str =~ s/>/&gt;/g;
    $str =~ s/</&lt;/g;
    $str =~ s/"/&quot;/g;
    $str =~ s/'/&#39;/g;
    return $str;
}

sub new {
    my ($klass, $message) = @_;
    my @trace;
    
    for (my $i = 1; my ($package, $file, $line) = caller($i); $i++) {
        push @trace, {
            file => $file,
            line => $line,
            func => undef,
        };
        if (my @c = caller($i + 1)) {
            $trace[-1]->{func} = $c[3]
                if $c[3];
        }
    }
    if ($message =~ / at ([^ ]+) line (\d+)\./
            && ($1 ne $trace[0]->{file} || $2 != $trace[0]->{line})) {
        unshift @trace, {
            file => $1,
            line => $2,
        };
    }
    
    bless {
        message => $message,
        trace   => \@trace,
    }, $klass;
}

sub _build_context {
    my ($file, $linenum) = @_;
    my $code;
    if (-f $file) {
        my $start = $linenum - 3;
        my $end   = $linenum + 3;
        $start = $start < 1 ? 1 : $start;
        open my $fh, '<:utf8', $file
            or die "cannot open $file:$!";
        my $cur_line = 0;
        while (my $line = <$fh>) {
            ++$cur_line;
            last if $cur_line > $end;
            next if $cur_line < $start;
            $line =~ s|\t|        |g;
            my @tag = $cur_line == $linenum
                ? (q{<b style="color: #000;background-color: #f99;">}, '</b>')
                    : ('', '');
            $code .= sprintf(
                '%s%5d: %s%s', $tag[0], $cur_line, _escape_html($line),
                $tag[1],
            );
        }
        close $file;
    }
    return $code;
}

sub as_html {
    my ($err, %args) = @_;
    my $msg = _escape_html($err->{message});
    my $out = qq{<!doctype html><head><title>500 Internal Server Error</title><style type="text/css">body { margin: 0; padding: 0; background: rgb(230, 230, 230); color: rgb(44, 44, 44); } h1 { margin: 0 0 .5em; padding: .25em .5em .1em 1.5em; border-bottom: thick solid rgb(0, 0, 15); background: rgb(63, 63, 63); color: rgb(239, 239, 239); font-size: x-large; } p { margin: .5em 1em; } li { font-size: small; } pre { background: rgb(255, 239, 239); color: rgb(47, 47, 47); font-size: medium; } pre code strong { color: rgb(0, 0, 0); background: rgb(255, 143, 143); } p.f { text-align: right; font-size: xx-small; } p.f span { font-size: medium; }</style></head><h1>500 Internal Server Error</h1><p>${msg}</p><ol>};
    for my $stack (@{$err->{trace}}) {
        $out .= join(
            '',
            '<li>',
            $stack->{func} ? _escape_html("in $stack->{func}") : '',
            ' at ',
            $stack->{file} ? _escape_html($stack->{file}) : '',
            ' line ',
            $stack->{line},
            q(<pre><code>),
            _build_context($stack->{file}, $stack->{line}),
            q(</code></pre></li>),
        );
    }
    $out .= qq{</ol><p class="f"><span>Powered by $args{powered_by}</p>};
    $out;
}

sub output {
    my ($err, %args) = @_;
    
    warn $err->{message};
    
    print "Status: 500\r\n";
    print "Content-type: text/html; charset=utf-8\r\n";
    print "\r\n";

    my $body = $args{renderer} ? $args{renderer}->($err, %args) : $err->as_html(%args);
    utf8::encode($body);
    print $body;
}

1;
