
sub do_index {
    my $REQ = shift;
    render('index.html');
}

sub do_goto_wassr {
    redirect('http://wassr.jp/');
}
