package Text::Hatena;
use strict;
use warnings;
use Carp;
use base qw(Class::Data::Inheritable);
use vars qw($VERSION);
use Parse::RecDescent;
use Text::Hatena::AutoLink;

$VERSION = '0.20';

my ($parser, $syntax);

__PACKAGE__->mk_classdata('syntax');

#$::RD_HINT = 1;
#$::RD_TRACE = 1;
#$::RD_WARN = undef;
$Parse::RecDescent::skip = '';
$syntax = q(
    body       : section(s)
    section    : h3(?) block(s?)
    # Block Elements
    block      : h5
               | h4
               | blockquote
               | dl
               | list
               | super_pre
               | pre
               | table
               | cdata
               | p
    h3         : "\n*" inline(s)
    h4         : "\n**" inline(s)
    h5         : "\n***" inline(s)
    blockquote : "\n>" http(?) ">" block(s) "\n<<" ..."\n"
    dl         : dl_item(s)
    dl_item    : "\n:" inline[term => ':'](s) ':' inline(s)
    list       : list_item[level => $arg{level} || 1](s)
    list_item  : "\n" /[+-]{$arg{level}}/ inline(s) list[level => $arg{level} + 1](?)
    super_pre  : /\n>\|(\w*)\|/o text_line(s) "\n||<" ..."\n"
    text_line  : ...!"\n||<\n" "\n" /[^\n]*/o
    pre        : "\n>|" pre_line(s) "\n|<" ..."\n"
    pre_line   : ...!"\n|<" "\n" inline(s?)
    table      : table_row(s)
    table_row  : "\n|" td(s /\|/) '|'
    td         : /\*?/o inline[term => '\|'](s)
    cdata      : "\n><" /.+?(?=><\n)/so "><" ..."\n"
    p          : ...!p_terminal "\n" inline(s?)
    p_terminal : h3 | "\n<<\n"
    # Inline Elements
    inline     : /[^\n$arg{term}]+/
    http       : /https?:\/\/[A-Za-z0-9~\/._\?\&=\-%#\+:\;,\@\']+(?::title=[^\]]+)?/
);

sub parse {
    my $class = shift;
    my $text = shift or return;
    $text =~ s/\r//g;
    $text = "\n" . $text unless $text =~ /^\n/;
    $text .= "\n" unless $text =~ /\n$/;
    my $node = shift || 'body';
    my $html = $class->parser->$node($text);
#    warn $html;
    return $html;
}

sub parser {
    my $class = shift;
    unless (defined $parser) {
         $::RD_AUTOACTION = q|my $method = shift @item;| .
             $class . q|->$method({items => \@item});|;
        $parser = Parse::RecDescent->new($syntax);
        if ($class->syntax) {
            $parser->Replace($class->syntax);
        }
    }
    return $parser;
}

sub expand {
    my $class = shift;
    my $array = shift or return;
    ref($array) eq 'ARRAY' or return;
    my $ret = '';
    while (my $item = shift @$array) {
        if (ref($item) eq 'ARRAY') {
            my $c = $class->expand($item);
            $ret .= $c if $c;
        } else {
            $ret .= $item if $item;
        }
    }
    return $ret;
}

# Nodes
# Block Nodes
sub abstract {
    my $class = shift;
    my $items = shift->{items};
    return $class->expand($items);
}

*body = \&abstract;
*block = \&abstract;
*line = \&abstract;

sub section {
    my $class = shift;
    my $items = shift->{items};
    my $body = $class->expand($items) || '';
    $body =~ s/\n\n$/\n/;
    return $body ? qq|<div class="section">\n| . $body . qq|</div>\n| : '';
}

sub h3 {
    my $class = shift;
    my $items = shift->{items};
    my $title = $class->expand($items->[1]);
    return if $title =~ /^\*/;
    return "<h3>$title</h3>\n";
}

sub h4 {
    my $class = shift;
    my $items = shift->{items};
    my $title = $class->expand($items->[1]);
    return if $title =~ /^\*/;
    return "<h4>$title</h4>\n";
}

sub h5 {
    my $class = shift;
    my $items = shift->{items};
    my $title = $class->expand($items->[1]);
    return "<h5>$title</h5>\n";
}

sub blockquote {
    my $class = shift;
    my $items = shift->{items};
    my $body = $class->expand($items->[3]);
    my $http = $items->[1]->[0];
    my $ret = '';
    if ($http) {
        $ret = qq|<blockquote title="$http->{title}" cite="$http->{cite}">\n|;
    } else {
        $ret = "<blockquote>\n";
    }
    $ret .= $body;
    if ($http) {
        $ret .= qq|<cite><a href="$http->{cite}">$http->{title}</a></cite>\n|;
    }
    $ret .= "</blockquote>\n";
    return $ret;
}

sub bq_block {
    my $class = shift;
    my $items = shift->{items};
    return $class->expand($items->[0]);
}

sub dl {
    my $class = shift;
    my $items = shift->{items};
    my $list = $class->expand($items->[0]);
    return "<dl>\n$list</dl>\n";
}

sub dl_item {
    my $class = shift;
    my $items = shift->{items};
    my $dt = $class->expand($items->[1]);
    my $dd = $class->expand($items->[3]);
    return "<dt>$dt</dt>\n<dd>$dd</dd>\n";
}

sub dt {
    my $class = shift;
    my $items = shift->{items};
    my $dt = $class->expand($items->[1]);
    return "<dt>$dt</dt>\n";
}

sub list {
    my $class = shift;
    my $items = shift->{items};
    my ($list,$tag);
    for my $li (@{$items->[0]}) {
        $tag ||= $li =~ /^\-/ ? 'ul' : 'ol';
        $li =~ s/^[+-]+//;
        $list .= $li;
    }
    return "<$tag>\n$list</$tag>\n";
}

sub list_item {
    my $class = shift;
    my $items = shift->{items};
    my $li = $class->expand($items->[2]);
    my $sl = $class->expand($items->[3]) || '';
    $sl = "\n" . $sl if $sl;
    return $items->[1] . "<li>$li$sl</li>\n";
}

sub super_pre {
    my $class = shift;
    my $items = shift->{items};
    my $filter = $1 || ''; # todo
    my $texts = $class->expand($items->[1]);
    return "<pre>\n$texts</pre>\n";
}

sub pre {
    my $class = shift;
    my $items = shift->{items};
    my $lines = $class->expand($items->[1]);
    return "<pre>\n$lines</pre>\n";
}

sub pre_line {
    my $class = shift;
    my $items = shift->{items};
    my $inlines = $class->expand($items->[2]);
    return "$inlines\n";
}

sub table {
    my $class = shift;
    my $items = shift->{items};
    my $trs = $class->expand($items->[0]);
    return "<table>\n$trs</table>\n";
}

sub table_row { # we can't use tr!
    my $class = shift;
    my $items = shift->{items};
    my $tds = $class->expand($items->[1]);
    return "<tr>\n$tds</tr>\n";
}

sub td {
    my $class = shift;
    my $items = shift->{items};
    my $tag = $items->[0] ? 'th' : 'td';
    my $inlines = $class->expand($items->[1]);
    return "<$tag>$inlines</$tag>\n";
}

sub cdata {
    my $class = shift;
    my $items = shift->{items};
    my $data = $items->[1];
    return "<$data>\n";
}

sub p {
    my $class = shift;
    my $items = shift->{items};
    my $inlines = $class->expand($items->[2]);
    return $inlines ? "<p>$inlines</p>\n" : "\n";
}

sub text_line {
    my $class = shift;
    my $text = shift->{items}->[2];
    return "$text\n";
}

# Inline Nodes
sub inline {
    my $class = shift;
    my $items = shift->{items};
    my $item = $items->[0] or return;
    $item = Text::Hatena::AutoLink->parse($item);
    return $item;
}

sub http {
    my $class = shift;
    my $items = shift->{items};
    my $item = $items->[0] or return;
    $item =~ s/:title=([^\]]+)$//;
    my $title = $1 || $item;
    return {
        cite => $item,
        title => $title,
    }
}

1;

__END__

=head1 NAME

Text::Hatena - Perl extension for formatting text with Hatena Style.

=head1 SYNOPSIS

  use Text::Hatena;

  my $html = Text::Hatena->parse($text);

=head1 DESCRIPTION

Text::Hatena parses text with Hatena Style and generates html string.
Hatena Style is a set of text syntax which is originally used in
Hatena Diary (http://d.hatena.ne.jp/).

You can get html string from simple text with syntax like Wiki.

=over 4

=item Incompatibility at version 0.20

All codes were rewritten at version 0.20 and some functions were removed.
API for parsing text were changed too. Please be careful to upgrade your
Text::Hatena to version 0.20+.

=back

=head1 METHODS

Here are common methods of Text::Hatena.

=over 4

=item parse

  my $html = $parser->parse($text);

parses text and returns html string.

=back

=head1 Text::Hatena Syntax

Text::Hatena supports some simple markup language, which is similar to the Wiki format.

=over 4

=item Paragraphs

Basically each line becomes a paragraph. If you want to force a newline in a paragraph, you can use a line break markup of HTML.

Text::Hatena treats a blank line as the end of a block. A blank line after a paragraph does not affect the output. Two blank lines are translated into a line break, three blank lines are translated into two line breaks and so on.

To stop generating paragraphs automatically, start a line with >< (greater-than sign and less-than sign). The first > (greater-than sign) will be omitted. If you end a line with ><, it will stop. The last < (less-than sign) will be omitted.

  ><div class="foo">A div block without paragraph.</div><

  ><form action="foo.cgi" method="put">
  To insert a from, write as you see here.
  <input type="text" name="a" />
  <input type="submit" />
  </form><

=item Headlines

To create a section headline, start a line with a star followed by an anchor, a star, some tags of categories and a section title.

  *A line with a star becomes section headline

More stars mean deeper levels of headlines. You can use up to three stars for headlines.

  **Start a line with two stars to create a 4th level headline
  ***Start a line with three stars to create a 5th level headline.

=item Lists and Tables

Text::Hatena supports ordered and unordered lists. Start every line with a minus (-) for unordered lists or a plus (+) for ordered ones. More marks mean deeper levels. You can show the end of the lists by a blank line.

  -Start a line with minuses to create an unordered list item.

  +Start a line with pluses to create an ordered list item.
  ++They can be nested.

Text::Hatena supports definition lists. Start every line with a colon followed by a term, a colon, and a description.

  :term:description

You can create tables by using a simple syntax. Table rows have to start and end with a vertical bar (|). Separete every cell with a vertical bar (|). To turn cells into headers, begin them with a star.

  |*header1|*header2|
  |colum1|colum2|

=item Blockquotes

To make a blockquote, enclose line(s) with >> (double greater-than sign) and << (double less-than sign). Marks should be placed in separate lines; don't start quoting line(s) with >> or end them with <<. Blockquotes may be nested.

  >>
  To make a blockquote, enclose line(s) with >> (double greater-than sign)
  and << (double less-than sign).
  <<

=item Preformatted texts

To make a preformatted text, enclose line(s) with >| (a greater-than sign followed by a vertical bar) and |< (a vertical var followed by a less-than sign).

Every >| should be placed in separate lines; don't start preformatted line(s) with >|. But some preformatted texts may be closed by |< after the last lines without separating lines.

  >|
  To make a preformatted text, enclose line(s) with >|
  (a greater-than sign followed by a vertical bar) and |<
  (a vertical var followed by a less-than sign).
  |<

This also works well.

  >|
  To make a preformatted text, enclose line(s) with >|
  (a greater-than sign followed by a vertical bar) and |<
  (a vertical var followed by a less-than sign).|<

To encode special characters into HTML entities, use >|| and ||< for >| and |<. The characters to be replaced are less-than signs (<), greater-than signs (>), double quotes ("), and ampersands (&).

  >||
  To encode special characters into HTML entities,
  use >|| and ||< for >| and |<.
  ||<

=back

=head1 SEE ALSO

http://d.hatena.ne.jp/ (Japanese)

=head1 AUTHOR

Junya Kondo, E<lt>jkondo@hatena.ne.jpE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) Hatena Inc. All Rights Reserved.

This library is free software; you may redistribute it and/or modify
it under the same terms as Perl itself.

=cut
