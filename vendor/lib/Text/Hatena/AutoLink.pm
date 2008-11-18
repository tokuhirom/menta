package Text::Hatena::AutoLink;
use strict;
use warnings;
use Carp;
use Regexp::Assemble;
use base qw(Class::Data::Inheritable);
use vars qw($VERSION);

__PACKAGE__->mk_classdata('syntax');
__PACKAGE__->syntax({});

$VERSION = '0.20';

my $ra;
my $syntax = {
    '\[\](.+?)\[\]' => \&unbracket,
    '(?:\[)?(ftp:\/\/[A-Za-z0-9~\/._\?\&=\-%#\+:\;,\@\']+)(?:\])?' => \&http,
    '(?:\[)?(https?:\/\/[A-Za-z0-9~\/._\?\&=\-%#\+:\;,\@\']+)(?:\])?' => \&http,
    '\[(https?:\/\/[A-Za-z0-9~\/._\?\&=\-%#\+:\;,\@\']+(?:jpg|jpeg|gif|png|bmp)):image(:[hw]\d+)?\]' => \&http_image,
    '\[(https?:\/\/[A-Za-z0-9~\/._\?\&=\-%#\+:\;,\@\']+):title=([^\]]+)\]' => \&http_title,
    '(?:\[)?mailto:(\w[\w\.-]+\@\w[\w\.\-]*\w)(?:\])?' => \&mailto,
};

sub parse {
    my $class = shift;
    my $text = shift;
    my $html = '';
    my $ra = $class->ra;
    while ($text && $ra->match($text)) {
        $html .= substr($text, 0, $ra->mbegin->[0]) if $ra->mbegin->[0];
        my $handler = $class->syntax->{$ra->matched} || $syntax->{$ra->matched};
        $html .= $handler->($ra->mvar());
        $text = substr($text, $ra->mend->[0]);
    }
    $html .= $text if $text;
    return $html;
}

sub ra {
    my $class = shift;
    unless ($ra) {
        $ra = Regexp::Assemble->new(
            flags => 'i',
            track => 1,
            reduce => 1,
        );
        $ra->add(keys %$syntax, keys %{$class->syntax});
    }
    return $ra;
}

sub unbracket {
    my $mvar = shift;
    return $mvar->[1];
}

sub http {
    my $mvar = shift;
    my $url = $mvar->[0];
    return sprintf('<a href="%s">%s</a>', $url, $url);
}

sub http_image {
    my $mvar = shift;
    my $url = $mvar->[1];
    my $size = '';
    if ($mvar->[2] && $mvar->[2] =~ /^:([hw])(\d+)$/o) {
        my $hw = $1 eq 'h' ? 'height' : 'width';
        $size = sprintf(qq|$hw="%d" |, $2);
    }
    return sprintf('<a href="%s"><img src="%s" alt="%s" %s/></a>',
                   $url, $url, $url, $size);
}

sub http_title {
    my $mvar = shift;
    my $url = $mvar->[1];
    my $title = $mvar->[2];
    return sprintf('<a href="%s">%s</a>', $url, $title);
}

sub mailto {
    my $mvar = shift;
    my $addr = $mvar->[1];
    return sprintf('<a href="mailto:%s">mailto:%s</a>', $addr, $addr);
}

1;

__END__

=head1 NAME

Text::AutoLink - Perl extension for making hyperlinks in text automatically.

=head1 SYNOPSIS

  use Text::Hatena::AutoLink;

  my $parser = Text::Hatena::AutoLink->new;
  my $html = $parser->parse($text);

=head1 DESCRIPTION

Text::Hatena::AutoLink makes many hyperlinks in text automatically.
Urls will be changed into hyperlinks.

=over 4

=item Incompatibility at version 0.20

All codes were rewritten at version 0.20 and some functions were removed.
API for parsing text were changed too. Please be careful to upgrade your
Text::Hatena::AutoLink to version 0.20+.

=back

=head1 METHODS

Here are common methods of Text::Hatena::AutoLink.

=over 4

=item parse

  my $html = $parser->parse($text);

parses text and make links. It returns html.

=back

=head1 Text::Hatena::AutoLink Syntax

Text::Hatena::AutoLink supports some simple syntaxes.

  http://www.hatena.ne.jp/
  [http://www.hatena.ne.jp/:title=Hatena]
  [http://www.hatena.ne.jp/images/top/h1.gif:image]
  [http://www.hatena.ne.jp/images/top/h1.gif:image:w300]
  mailto:someone@example.com

These lines all become into hyperlinks.

  []http://dont.link.to.me/[]

You can avoid being hyperlinked with 2 pair brackets like the above line.

=head1 SEE ALSO

L<Text::Hatena>

=head1 AUTHOR

Junya Kondo, E<lt>jkondo@hatena.ne.jpE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) Hatena Inc. All Rights Reserved.

This library is free software; you may redistribute it and/or modify
it under the same terms as Perl itself.

=cut
