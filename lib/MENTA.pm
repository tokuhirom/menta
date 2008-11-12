package MENTA;
use strict;
use warnings;
use utf8;
use constant DEFAULT_MAX_POST_BODY => 1_024_000;

our $FINISHED;
our $REQ;
our $CONFIG;

sub config {
    if (@_) {
        my $config = @_ == 1 ? $_[0] : {@_};
        $config->{menta}->{max_post_body} ||= DEFAULT_MAX_POST_BODY;
        $CONFIG = $config;
    }

    $CONFIG
}

sub run {
    eval {
        my $input;
        if ($ENV{'REQUEST_METHOD'} eq "POST") {
            if ($ENV{CONTENT_LENGTH} > $CONFIG->{menta}->{max_post_body}) {
                die "投稿データが長すぎです";
            } else {
                read(STDIN, $input, $ENV{'CONTENT_LENGTH'});
            }
        } else {
            $input = $ENV{QUERY_STRING};
        }
        local $REQ = {};
        local $FINISHED = 0;

        for ( split /&/, $input) {
            my ($key, $val) = split /=/, $_;
            $val =~ tr/+/ /;
            $val =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("H2", $1)/eg;
            $REQ->{$key} = $val;
        }

        {
            my $mode = $REQ->{mode} || 'index';
            my $meth = "do_$mode";
            if (my $code = main->can($meth)) {
                $code->($REQ);
                unless ($FINISHED) {
                    die "なにも出力してません";
                }
            } else {
                die "'$mode' というモードは存在しません";
            }
        }
    };
    if (my $err = $@) {
        # TODO: 美麗な画面を出す
        warn $err;

        print "Content-Type: text/html; charset=utf-8\n";
        print "\n";
        if ($CONFIG->{menta}->{kcatch_mode}) {
            print qq{<html><body><div color="red">500 Internal Server Error: $err</div></body></html>\n};
        } else {
            print qq{<html><body><div color="red">500 Internal Server Error</div></body></html>\n};
        }
    }
}

1;
