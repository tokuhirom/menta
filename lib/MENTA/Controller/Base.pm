package MENTA::Controller::Base;
use strict;
use warnings;
use utf8;

our @METHODS = qw/render redirect finalize/;

# TODO: ディレクトリトラバーサル対策
sub render {
    my ($tmpl, @params) = @_;
    my $tmpldir = MENTA::config->{menta}->{tmpl_dir} or die "[menta] セクションに tmpl_dir が設定されていません";
    my $tmplfname = "$tmpldir/$tmpl";
    die "$tmplfname という名前のテンプレートファイルは見つかりません" unless -f $tmplfname;
    my $tmplcode = do $tmplfname;
    die $@ if $@;
    my $out = $tmplcode->(@params);
    utf8::encode($out);

    print "Content-Type: text/html; charset=utf-8\n";
    print "\n";
    print $out;

    $MENTA::FINISHED++;
}

sub redirect {
    my ($location, ) = @_;
    print "Status: 302\n";
    print "Location: $location\n";
    print "\n";

    $MENTA::FINISHED++;
}

sub finalize {
    my $str = shift;
    my $content_type = shift || 'text/html; charset=utf-8';

    print "Content-Type: $content_type\n";
    print "\n";
    print $str;
    
    $MENTA::FINISHED++;
}

1;
