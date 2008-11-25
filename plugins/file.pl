package MENTA::Plugin::File;
use MENTA::Plugin;

sub file_read {
    my $fname = shift;
    open my $fh, '<:utf8', $fname
      or die "${fname} を読み込み用に開けません: $!";
    my $s = do { local $/; join '', <$fh> };
    close $fh;
    $s;
}

sub file_write {
    my ( $fname, $stuff ) = @_;
    open my $fh, '>:utf8', $fname
      or die "${fname} を書き込み用に開けません: $!";
    print $fh $stuff;
    close $fh;
}

1;
