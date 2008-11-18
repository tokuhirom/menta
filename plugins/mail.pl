package MENTA::Plugin::Mail;
use MENTA::Plugin;
use Symbol ();

# XXX windows で動かないかな。
my $find_sendmail = sub {
    for my $dir ( split /:/, $ENV{PATH} ) {
        if ( -x "$dir/sendmail" ) {
            return "$dir/sendmail";
        }
    }
    return;
};

sub mail_send {
    my ($to, $subject, $body, $additional_headers) = @_;
    die "To に改行を含めることはできません" if $to =~ /[\r\n]/;

    local $SIG{CHLD} = "DEFAULT";

    my $mailer = $find_sendmail->() or die "sendmail が見つかりません";

    my $pipe = Symbol::gensym();
    open $pipe, "| $mailer -t -oi" || die "$mailer を開けませんでした: $!";

    my @lines;
    push @lines, "To: $to\r\n";
    push @lines, $additional_headers if $additional_headers;
    push @lines, "\r\n";
    push @lines, $body;
    print $pipe join('', @lines) || die "$mailer に書き込めません: $!";

    close $pipe || die "閉じれません: $mailer, $!";
}

1;
__END__
#   mb_send_mail('to@example.jp', 'サブジェクト', '本文', 'From: from@example.jp');
# という風にして、送るとよい。
# TODO: ヘッダの処理とかが甘いので、なんとかする
# iso-2022-jp に MIME encode する？

