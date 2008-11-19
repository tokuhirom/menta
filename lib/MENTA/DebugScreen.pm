package MENTA::DebugScreen;
use strict;
use warnings;

# MENTA => NanoA => MENTA

sub build {
    my $msg = shift;
    my @trace;
    for (my $i = 1; my ($package, $file, $line) = caller($i); $i++) {
        push @trace, [ $file, $line ];
    }
    if ($msg =~ / at ([^ ]+) line (\d+)\./ && ($1 ne $trace[0]->[0] || $2 != $trace[0]->[1])) {
        unshift @trace, [ $1, $2 ];
    }
    @trace = map {
        +{
            level    => $_ + 1,
            filename => $trace[$_]->[0],
            line     => $trace[$_]->[1],
            context  => build_context(@{$trace[$_]}),
        }
    } 0..$#trace;
    
    +{ message => $msg, trace => \@trace };
}

sub build_context {
    my ( $file, $linenum ) = @_;
    my $code;
    warn "HOGE: $file";
    if ( -f $file ) {
        my $start = $linenum - 3;
        my $end   = $linenum + 3;
        $start = $start < 1 ? 1 : $start;
        open my $fh, '<:utf8', $file or die "cannot open $file";
        my $cur_line = 0;
        while ( my $line = <$fh> ) {
            ++$cur_line;
            last if $cur_line > $end;
            next if $cur_line < $start;
            $line =~ s|\t|        |g;
            my @tag =
                $cur_line == $linenum
                    ? (q{<b style="color: #000;background-color: #f99;">}, '</b>')
                        : ( '', '' );
            $code .= sprintf( '%s%5d: %s%s',
                              $tag[0], $cur_line,
                              main::escape_html($line),
                              $tag[1], );
        }
        close $file;
    }
    warn "END $file";
    return $code;
}

sub output {
    my $err = shift;
    
    warn $err->{message};
    
    print "Status: 500\r\n";
    print "Content-type: text/html; charset=utf-8\r\n";
    print "\r\n";
    
    my $body = do {
        my $msg = main::escape_html($err->{message});
        my $out = qq{<!doctype html><head><title>500 Internal Server Error</title><style type="text/css">body { margin: 0; padding: 0; background: rgb(230, 230, 230); color: rgb(44, 44, 44); } h1 { margin: 0 0 .5em; padding: .25em .5em .1em 1.5em; border-bottom: thick solid rgb(0, 0, 15); background: rgb(63, 63, 63); color: rgb(239, 239, 239); font-size: x-large; } p { margin: .5em 1em; } li { font-size: small; } pre { background: rgb(255, 239, 239); color: rgb(47, 47, 47); font-size: medium; } pre code strong { color: rgb(0, 0, 0); background: rgb(255, 143, 143); } p.f { text-align: right; font-size: xx-small; } p.f span { font-size: medium; }</style></head><h1>500 Internal Server Error</h1><p>${msg}</p><ol>};
        for my $stack (@{$err->{trace}}) {
            $out .= '<li>' . main::escape_html(join(', ', $stack->{package}, $stack->{filename}, $stack->{line}))
                                        . qq(<pre><code>$stack->{context}</code></pre></li>);
        }
        $out .= qq{</ol><p class="f"><span>Powered by <strong>MENTA</strong></span>, Web application framework</p>};
        $out;
    };
    utf8::encode($body);
    print $body;
}

"ENDOFMODULE";
