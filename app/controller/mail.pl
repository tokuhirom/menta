use MENTA;

load_plugin("mail");

sub do_mail {
    mail_send('info@example.com', 'this is subject', 'hi!');
    redirect('http://example.com');
}

