use MENTA;

sub do_mail {
    mail_send('info@example.com', 'this is subject', 'hi!');
    redirect('http://example.com');
}

