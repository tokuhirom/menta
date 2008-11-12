### SHEBANG ###
use strict;
use warnings;
use utf8;

{
    package MENTA::Controller;
    use strict;
    use warnings;
    use utf8;
    use Encode;

    # TODO: ディレクトリトラバーサル対策
    sub render {
        my ($tmpl, @params) = @_;
        my $tmpldir = MENTA->config->{menta}->{tmpl_dir} or die "[menta] セクションに tmpl_dir が設定されていません";
        my $tmplfname = "$tmpldir/$tmpl";
        die "$tmplfname という名前のテンプレートファイルは見つかりません" unless -f $tmplfname;
        my $tmplcode = do $tmplfname;
        die $@ if $@;

        print "Content-type: text/html; charset=utf-8\n";
        print "\n";
        print encode_utf8($tmplcode->(@params));

        $MENTA::FINISHED++;
    }

    sub redirect {
        my ($location, ) = @_;
        print "Status: 302\n";
        print "Location: $location\n";
        print "\n";

        $MENTA::FINISHED++;
    }

    ### CONTROLLER ###

    1;
}

### MAIN ###

package main;
### CONFIG ###
MENTA->run();

