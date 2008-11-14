use Fcntl ':flock';
use utf8;

sub do_counter {
    my $fname = config->{application}->{counterfile} or die "データファイル名が設定されていません";
    my $mode = (-f $fname) ? '+<' : '+>';
    open my $fh, $mode, $fname or die "$fname を開けません: $!";
    flock $fh, LOCK_EX;
    my $cnt = <$fh>;
    $cnt++;
    seek($fh, 0, "SEEK_SET");
    print $fh $cnt or die "$fname にかきこめません: $!";
    flock $fh, LOCK_UN;
    close $fh or die "$fname を閉じることができません: $!";
    finalize($cnt);
}

