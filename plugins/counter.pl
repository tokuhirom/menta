use MENTA;
use Fcntl ':flock';

sub counter_increment {
    my $fname = shift;
    unless ($fname) {
        $fname = config->{application}->{counter}->{file} or die "config.application.counter.file にデータファイル名が設定されていません";
    }
    my $mode = (-f $fname) ? '+<' : '+>';
    open my $fh, $mode, $fname or die "$fname を開けません: $!";
    flock $fh, LOCK_EX;
    my $cnt = <$fh>;
    $cnt++;
    seek($fh, 0, SEEK_SET);
    print $fh $cnt or die "$fname にかきこめません: $!";
    flock $fh, LOCK_UN;
    close $fh or die "$fname を閉じることができません: $!";
    $cnt;
}

1;
