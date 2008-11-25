package MENTA::Plugin::Counter;
use MENTA::Plugin;
use Fcntl ':flock', ':seek';
use Carp;

sub counter_increment {
    my $fname = shift;
    croak "ファイル名の指定がありません" unless $fname;
    $fname = data_dir() . '/' . $fname;
    my $mode = (-f $fname) ? '+<' : '+>';
    open my $fh, $mode, $fname or die "$fname を開けません: $!";
    flock $fh, LOCK_EX;
    my $cnt = <$fh>;
    $cnt++;
    seek $fh, 0, SEEK_SET;
    print $fh $cnt or die "$fname にかきこめません: $!";
    flock $fh, LOCK_UN;
    close $fh or die "$fname を閉じることができません: $!";
    $cnt;
}

1;
