package CGI::ExceptionManager::StackTrace::CGI;
use strict;
use warnings;
use base qw/CGI::ExceptionManager::StackTrace/;

sub output {
    my ($err, %args) = @_;
    
    warn $err->{message};
    
    print "Status: 500\r\n";
    print "Content-type: text/html; charset=utf-8\r\n";
    print "\r\n";

    my $body = $args{renderer} ? $args{renderer}->($err, %args) : $err->as_html(%args);
    utf8::encode($body);
    print $body;
}

1;
