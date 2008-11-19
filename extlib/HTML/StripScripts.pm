package HTML::StripScripts;
use strict;
use warnings FATAL => 'all';

use vars qw($VERSION);
$VERSION = '1.04';

=head1 NAME

HTML::StripScripts - Strip scripting constructs out of HTML

=head1 SYNOPSIS

  use HTML::StripScripts;

  my $hss = HTML::StripScripts->new({ Context => 'Inline' });

  $hss->input_start_document;

  $hss->input_start('<i>');
  $hss->input_text('hello, world!');
  $hss->input_end('</i>');

  $hss->input_end_document;

  print $hss->filtered_document;

=head1 DESCRIPTION

This module strips scripting constructs out of HTML, leaving as
much non-scripting markup in place as possible.  This allows web
applications to display HTML originating from an untrusted source
without introducing XSS (cross site scripting) vulnerabilities.

You will probably use L<HTML::StripScripts::Parser> rather than using
this module directly.

The process is based on whitelists of tags, attributes and attribute
values.  This approach is the most secure against disguised scripting
constructs hidden in malicious HTML documents.

As well as removing scripting constructs, this module ensures that
there is a matching end for each start tag, and that the tags are
properly nested.

Previously, in order to customise the output, you needed to subclass
C<HTML::StripScripts> and override methods.  Now, most customisation
can be done through the C<Rules> option provided to C<new()>. (See
examples/declaration/ and examples/tags/ for cases where subclassing is
necessary.)

The HTML document must be parsed into start tags, end tags and
text before it can be filtered by this module.  Use either
L<HTML::StripScripts::Parser> or L<HTML::StripScripts::Regex> instead
if you want to input an unparsed HTML document.

See examples/direct/ for an example of how to feed tokens directly to
 HTML::StripScripts.

=head1 CONSTRUCTORS

=over

=item new ( CONFIG )

Creates a new C<HTML::StripScripts> filter object, bound to a
particular filtering policy.  If present, the CONFIG parameter
must be a hashref.  The following keys are recognized (unrecognized
keys will be silently ignored).

    $s = HTML::Stripscripts->new({
        Context         => 'Document|Flow|Inline|NoTags',
        BanList         => [qw( br img )] | {br => '1', img => '1'},
        BanAllBut       => [qw(p div span)],
        AllowSrc        => 0|1,
        AllowHref       => 0|1,
        AllowRelURL     => 0|1,
        AllowMailto     => 0|1,
        EscapeFiltered  => 0|1,
        Rules           => { See below for details },
    });

=over

=item C<Context>

A string specifying the context in which the filtered document
will be used.  This influences the set of tags that will be
allowed.

If present, the C<Context> value must be one of:

=over

=item C<Document>

If C<Context> is C<Document> then the filter will allow a full
HTML document, including the C<HTML> tag and C<HEAD> and C<BODY>
sections.

=item C<Flow>

If C<Context> is C<Flow> then most of the cosmetic tags that one
would expect to find in a document body are allowed, including
lists and tables but not including forms.

=item C<Inline>

If C<Context> is C<Inline> then only inline tags such as C<B>
and C<FONT> are allowed.

=item C<NoTags>

If C<Context> is C<NoTags> then no tags are allowed.

=back

The default C<Context> value is C<Flow>.

=item C<BanList>

If present, this option must be an arrayref or a hashref.  Any tag that
would normally be allowed (because it presents no XSS hazard) will be
blocked if the lowercase name of the tag is in this list.

For example, in a guestbook application where C<HR> tags are used to
separate posts, you may wish to prevent posts from including C<HR>
tags, even though C<HR> is not an XSS risk.

=item C<BanAllBut>

If present, this option must be reference to an array holding a list of
lowercase tag names.  This has the effect of adding all but the listed
tags to the ban list, so that only those tags listed will be allowed.

=item C<AllowSrc>

By default, the filter won't allow constructs that cause the browser to
fetch things automatically, such as C<SRC> attributes in C<IMG> tags.
If this option is present and true then those constructs will be
allowed.

=item C<AllowHref>

By default, the filter won't allow constructs that cause the browser to
fetch things if the user clicks on something, such as the C<HREF>
attribute in C<A> tags.  Set this option to a true value to allow this
type of construct.

=item C<AllowRelURL>

By default, the filter won't allow relative URLs such as C<../foo.html>
in C<SRC> and C<HREF> attribute values.  Set this option to a true value
to allow them. C<AllowHref> and / or C<AllowSrc> also need to be set to true
for this to have any effect.

=item C<AllowMailto>

By default, C<mailto:> links are not allowed. If C<AllowMailto> is set to
a true value, then this construct will be allowed. This can be enabled
separately from AllowHref.

=item C<EscapeFiltered>

By default, any filtered tags are outputted as C<< <!--filtered--> >>. If
C<EscapeFiltered> is set to a true value, then the filtered tags are converted
to HTML entities.

For instance:

  <br>  -->  &lt;br&gt;

=item C<Rules>

The C<Rules> option provides a very flexible way of customising the filter.

The focus is safety-first, so it is applied after all of the previous validation.
This means that you cannot all malicious data should already have been cleared.

Rules can be specified for tags and for attributes. Any tag or attribute
not explicitly listed will be handled by the default C<*> rules.

The following is a synopsis of all of the options that you can use to
configure rules.  Below, an example is broken into sections and explained.

 Rules => {

     tag => 0 | 1 | sub { tag_callback }
            | {
                attr      => 0 | 1 | 'regex' | qr/regex/ | sub { attr_callback},
                '*'       => 0 | 1 | 'regex' | qr/regex/ | sub { attr_callback},
                required  => [qw(attrname attrname)],
                tag       => sub { tag_callback }
              },

    '*' => 0 | 1 | sub { tag_callback }
           | {
               attr => 0 | 1 | 'regex' | qr/regex/ | sub { attr_callback},
               '*'  => 0 | 1 | 'regex' | qr/regex/ | sub { attr_callback},
               tag  => sub { tag_callback }
             }

    }

EXAMPLE:

    Rules => {

        ##########################
        ##### EXPLICIT RULES #####
        ##########################

        ## Allow <br> tags, reject <img> tags
        br          => 1,
        img         => 0,

        ## Send all <div> tags to a sub
        div         => sub { tag_callback },

        ## Allow <blockquote> tags,and allow the 'cite' attribute
        ## All other attributes are handled by the default C<*>
        blockquote  => {
            cite    => 1,
        },

        ## Allow <a> tags, and
        a  => {

            ## Allow the 'title' attribute
            title     => 1,

            ## Allow the 'href' attribute if it matches the regex
            href    =>   '^http://yourdomain.com'
       OR   href    => qr{^http://yourdomain.com},

            ## 'style' attributes are handled by a sub
            style     => sub { attr_callback },

            ## All other attributes are rejected
            '*'       => 0,

            ## Additionally, the <a> tag should be handled by this sub
            tag       => sub { tag_callback},

            ## If the <a> tag doesn't have these attributes, filter the tag
            required  => [qw(href title)],

        },

        ##########################
        ##### DEFAULT RULES #####
        ##########################

        ## The default '*' rule - accepts all the same options as above.
        ## If a tag or attribute is not mentioned above, then the default
        ## rule is applied:

        ## Reject all tags
        '*'         => 0,

        ## Allow all tags and all attributes
        '*'         => 1,

        ## Send all tags to the sub
        '*'         => sub { tag_callback },

        ## Allow all tags, reject all attributes
        '*'         => { '*'  => 0 },

        ## Allow all tags, and
        '*' => {

            ## Allow the 'title' attribute
            title   => 1,

            ## Allow the 'href' attribute if it matches the regex
            href    =>   '^http://yourdomain.com'
       OR   href    => qr{^http://yourdomain.com},

            ## 'style' attributes are handled by a sub
            style   => sub { attr_callback },

            ## All other attributes are rejected
            '*'     => 0,

            ## Additionally, all tags should be handled by this sub
            tag     => sub { tag_callback},

        },

=over

=item Tag Callbacks

    sub tag_callback {
        my ($filter,$element) = (@_);

        $element = {
            tag      => 'tag',
            content  => 'inner_html',
            attr     => {
                attr_name => 'attr_value',
            }
        };
        return 0 | 1;
    }

A tag callback accepts two parameters, the C<$filter> object and the C$element>.
It should return C<0> to completely ignore the tag and its content (which includes
any nested HTML tags), or C<1> to accept and output the tag.

The C<$element> is a hash ref containing the keys:

=item C<tag>

This is the tagname in lowercase, eg C<a>, C<br>, C<img>. If you set
the tag value to an empty string, then the tag will not be outputted, but
the tag contents will.

=item C<content>

This is the equivalent of DOM's innerHTML. It contains the text content
and any HTML tags contained within this element. You can change the content
or set it to an empty string so that it is not outputted.

=item C<attr>

C<attr> contains a hashref containing the attribute names and values

=back

If for instance, you wanted to replace C<< <b> >> tags with C<< <span> >> tags,
you could do this:

    sub b_callback {
        my ($filter,$element)   = @_;
        $element->{tag}         = 'span';
        $element->{attr}{style} = 'font-weight:bold';
        return 1;
    }

=item Attribute Callbacks

    sub attr_callback {
        my ( $filter, $tag, $attr_name, $attr_val ) = @_;
        return undef | '' | 'value';
    }

Attribute callbacks accept four parameters, the C<$filter> object, the C<$tag>
name, the C<$attr_name> and the C<$attr_value>.

It should return either C<undef> to reject the attribute, or the value to be
used. An empty string keeps the attribute, but without a value.

=item C<BanList> vs C<BanAllBut> vs C<Rules>

It is not necessary to use C<BanList> or C<BanAllBut> - everything can be done
via C<Rules>, however it may be simpler to write:

    BanAllBut => [qw(p div span)]

The logic works as follows:

   * If BanAllBut exists, then ban everything but the tags in the list
   * Add to the ban list any elements in BanList
   * Any tags mentioned explicitly in Rules (eg a => 0, br => 1)
     are added or removed from the BanList
   * A default rule of { '*' => 0 } would ban all tags except
     those mentioned in Rules
   * A default rule of { '*' => 1 } would allow all tags except
     those disallowed in the ban list, or by explicit rules

=back

=cut

sub new {
    my ( $pkg, $cfg ) = @_;

    my $self = bless {}, ref $pkg || $pkg;
    $self->hss_init($cfg);
    return $self;
}

=back

=head1 METHODS

This class provides the following methods:

=over

=item hss_init ()

This method is called by new() and does the actual initialisation work
for the new HTML::StripScripts object.

=cut

sub hss_init {
    my ( $self, $cfg ) = @_;
    $cfg ||= {};

    $self->{_hssCfg} = $cfg;

    $self->{_hssContext} = $self->init_context_whitelist;
    $self->{_hssAttrib}  = $self->init_attrib_whitelist;
    $self->{_hssAttVal}  = $self->init_attval_whitelist;
    $self->{_hssStyle}   = $self->init_style_whitelist;
    $self->{_hssDeInter} = $self->init_deinter_whitelist;
    $self->{_hssBanList} = $self->_hss_prepare_ban_list($cfg);
    $self->{_hssRules}   = $self->_hss_prepare_rules($cfg);
}

=item input_start_document ()

This method initializes the filter, and must be called once before
starting on each HTML document to be filtered.

=cut

sub input_start_document {
    my ( $self, $context ) = @_;

    $self->{_hssStack} = [ { NAME    => '',
                             CTX     => $self->{_hssCfg}{Context} || 'Flow',
                             CONTENT => '',
                           }
    ];
    $self->{_hssOutput} = '';

    $self->output_start_document;
}

=item input_start ( TEXT )

Handles a start tag from the input document.  TEXT must be the
full text of the tag, including angle-brackets.

=cut

sub input_start {
    my ( $self, $text ) = @_;

    $self->_hss_accept_input_start($text) or $self->reject_start($text);
}

sub _hss_accept_input_start {
    my ( $self, $text ) = @_;

    return 0 unless $text =~ m|^<([a-zA-Z0-9]+)\b(.*)>$|m;
    my ( $tag, $attr ) = ( lc $1, $self->strip_nonprintable($2) );

    return 0 if $self->{_hssSkipToEnd};
    if ( $tag eq 'script' or $tag eq 'style' ) {
        $self->{_hssSkipToEnd} = $tag;
        return 0;
    }

    return 0 if $self->_hss_tag_is_banned($tag);

    my $allowed_attr = $self->{_hssAttrib}{$tag};
    return 0 unless defined $allowed_attr;

    return 0 unless $self->_hss_get_to_valid_context($tag);

    my $default_filters = $self->{_hssRules}{'*'};
    my $tag_filters     = $self->{_hssRules}{$tag}
        || $default_filters;

    my %filtered_attr;
    while ( $attr
           =~ s#^\s*([\w\-]+)(?:\s*=\s*(?:([^"'>\s]+)|"([^"]*)"|'([^']*)'))?## )
    {
        my $key = lc $1;
        my $val = (   defined $2 ? $self->unquoted_to_canonical_form($2)
                    : defined $3 ? $self->quoted_to_canonical_form($3)
                    : defined $4 ? $self->quoted_to_canonical_form($4)
                    : ''
        );

        my $value_class = $allowed_attr->{$key};
        next unless defined $value_class;

        my $attval_handler = $self->{_hssAttVal}{$value_class};
        next unless defined $attval_handler;

        my $attr_filter;
        if ($tag_filters) {
            $attr_filter =
                $self->_hss_get_attr_filter( $default_filters, $tag_filters,
                                             $key );

            # filter == 0
            next unless $attr_filter;
        }

        my $filtered_value = &{$attval_handler}( $self, $tag, $key, $val );
        next unless defined $filtered_value;

        # send value to filter if sub
        if ( $tag_filters && ref $attr_filter ) {
            $filtered_value
                = $attr_filter->( $self, $tag, $key, $filtered_value );
            next unless defined $filtered_value;
        }

        $filtered_attr{$key} = $filtered_value;

    }

    # Check required attributes
    if ( my $required = $tag_filters->{required} ) {
        foreach my $key (@$required) {
            return 0
                unless length( $filtered_attr{$key} || '' );
        }
    }

    # Check for callback
    my $tag_callback = $tag_filters && $tag_filters->{tag}
        || $default_filters->{tag};

    my $new_context = $self->{_hssContext}{ $self->{_hssStack}[0]{CTX} }{$tag};

    my %stack_entry = ( NAME     => $tag,
                        ATTR     => \%filtered_attr,
                        CTX      => $new_context,
                        CALLBACK => $tag_callback,
                        CONTENT  => '',
    );
    if ( $new_context eq 'EMPTY' ) {
        $self->output_stack_entry( \%stack_entry );
    }
    else {
        unshift @{ $self->{_hssStack} }, \%stack_entry;

    }

    return 1;
}

=item input_end ( TEXT )

Handles an end tag from the input document.  TEXT must be the
full text of the end tag, including angle-brackets.

=cut

sub input_end {
    my ( $self, $text ) = @_;

    $self->_hss_accept_input_end($text) or $self->reject_end($text);
}

sub _hss_accept_input_end {
    my ( $self, $text ) = @_;

    return 0 unless $text =~ m#^</(\w+)>$#;
    my $tag = lc $1;

    if ( $self->{_hssSkipToEnd} ) {
        if ( $self->{_hssSkipToEnd} eq $tag ) {
            delete $self->{_hssSkipToEnd};
        }
        return 0;
    }

    # Ignore a close without an open
    return 0 unless grep { $_->{NAME} eq $tag } @{ $self->{_hssStack} };

    # Close open tags up to the matching open
    my @close = ();

    while ( scalar @{ $self->{_hssStack} } ) {
        my $entry = shift @{ $self->{_hssStack} };
        push @close, $entry;
        $self->output_stack_entry($entry);
        $entry->{CONTENT} = '';
        last if $entry->{NAME} eq $tag;
    }

    # Reopen any we closed early if all that were closed are
    # configured to be auto de-interleaved.
    unless ( grep { !$self->{_hssDeInter}{ $_->{NAME} } } @close ) {
        pop @close;
        unshift @{ $self->{_hssStack} }, @close;
    }

    return 1;
}

=item input_text ( TEXT )

Handles some non-tag text from the input document.

=cut

sub input_text {
    my ( $self, $text ) = @_;

    return if $self->{_hssSkipToEnd};

    $text = $self->strip_nonprintable($text);

    if ( $text =~ /^(\s*)$/ ) {
        $self->output_text($1);
        return;
    }

    unless ( $self->_hss_get_to_valid_context('CDATA') ) {
        $self->reject_text($text);
        return;
    }

    my $filtered = $self->filter_text( $self->text_to_canonical_form($text) );
    $self->output_text( $self->canonical_form_to_text($filtered) );
}

=item input_process ( TEXT )

Handles a processing instruction from the input document.

=cut

sub input_process {
    my ( $self, $text ) = @_;

    $self->reject_process($text);
}

=item input_comment ( TEXT )

Handles an HTML comment from the input document.

=cut

sub input_comment {
    my ( $self, $text ) = @_;

    $self->reject_comment($text);
}

=item input_declaration ( TEXT )

Handles an declaration from the input document.

=cut

sub input_declaration {
    my ( $self, $text ) = @_;

    $self->reject_declaration($text);
}

=item input_end_document ()

Call this method to signal the end of the input document.

=cut

sub input_end_document {
    my ($self) = @_;

    delete $self->{_hssSkipToEnd};

    while ( @{ $self->{_hssStack} } > 1 ) {
        $self->output_stack_entry( shift @{ $self->{_hssStack} } );
    }

    $self->output_end_document;
    my $last_entry = shift @{ $self->{_hssStack} };
    $self->{_hssOutput} = $last_entry->{CONTENT};
    delete $self->{_hssStack};

}

=item filtered_document ()

Returns the filtered document as a string.

=cut

sub filtered_document {
    my ($self) = @_;
    $self->{_hssOutput};
}

=back

=cut

=head1 SUBCLASSING

The only reason for subclassing this module now is to add to the
list of accepted tags, attributes and styles (See
L</"WHITELIST INITIALIZATION METHODS">).  Everything else can be
achieved with L</"Rules">.

The C<HTML::StripScripts> class is subclassable.  Filter objects are plain
hashes and C<HTML::StripScripts> reserves only hash keys that start with
C<_hss>.  The filter configuration can be set up by invoking the
hss_init() method, which takes the same arguments as new().

=head1 OUTPUT METHODS

The filter outputs a stream of start tags, end tags, text, comments,
declarations and processing instructions, via the following C<output_*>
methods.  Subclasses may override these to intercept the filter output.

The default implementations of the C<output_*> methods pass the
text on to the output() method.  The default implementation of the
output() method appends the text to a string, which can be fetched with
the filtered_document() method once processing is complete.

If the output() method or the individual C<output_*> methods are
overridden in a subclass, then filtered_document() will not work in
that subclass.

=over

=item output_start_document ()

This method gets called once at the start of each HTML document passed
through the filter.  The default implementation does nothing.

=cut

sub output_start_document { }

=item output_end_document ()

This method gets called once at the end of each HTML document passed
through the filter.  The default implementation does nothing.

=cut

*output_end_document = \&output_start_document;

=item output_start ( TEXT )

This method is used to output a filtered start tag.

=cut

sub output_start { $_[0]->output( $_[1] ) }

=item output_end ( TEXT )

This method is used to output a filtered end tag.

=cut

*output_end = \&output_start;

=item output_text ( TEXT )

This method is used to output some filtered non-tag text.

=cut

*output_text = \&output_start;

=item output_declaration ( TEXT )

This method is used to output a filtered declaration.

=cut

*output_declaration = \&output_start;

=item output_comment ( TEXT )

This method is used to output a filtered HTML comment.

=cut

*output_comment = \&output_start;

=item output_process ( TEXT )

This method is used to output a filtered processing instruction.

=cut

*output_process = \&output_start;

=item output ( TEXT )

This method is invoked by all of the default C<output_*> methods.  The
default implementation appends the text to the string that the
filtered_document() method will return.

=cut

sub output { $_[0]->{_hssStack}[0]{CONTENT} .= $_[1]; }

=item output_stack_entry ( TEXT )

This method is invoked when a tag plus all text and nested HTML content
within the tag has been processed. It adds the tag plus its content
to the content for its parent tag.

=cut

sub output_stack_entry {
    my ( $self, $tag ) = @_;

    my %entry;
    @entry{qw(tag attr content)} = @{$tag}{qw(NAME ATTR CONTENT)};

    if ( my $tag_callback = $tag->{CALLBACK} ) {
        $tag_callback->( $self, \%entry )
            or return;
    }

    my $tagname        = $entry{tag};
    my $filtered_attrs = $self->_hss_join_attribs( $entry{attr} );

    if ( $tag->{CTX} eq 'EMPTY' ) {
        $self->output_start("<$tagname$filtered_attrs />")
            if $entry{tag};
        return;
    }
    if ($tagname) {
        $self->output_start("<$tagname$filtered_attrs>");
    }

    if ( $entry{content} ) {
        $self->{_hssStack}[0]{CONTENT} .= $entry{content};
    }

    if ($tagname) {
        $self->output_end("</$tagname>");
    }
}

=back

=head1 REJECT METHODS

When the filter encounters something in the input document which it
cannot transform into an acceptable construct, it invokes one of
the following C<reject_*> methods to put something in the output
document to take the place of the unacceptable construct.

The TEXT parameter is the full text of the unacceptable construct.

The default implementations of these methods output an HTML comment
containing the text C<filtered>. If L</"EscapeFiltered">
is set to true, then the rejected text is HTML escaped instead.

Subclasses may override these methods, but should exercise caution.
The TEXT parameter is unfiltered input and may contain malicious
constructs.

=over

=item reject_start ( TEXT )

=item reject_end ( TEXT )

=item reject_text ( TEXT )

=item reject_declaration ( TEXT )

=item reject_comment ( TEXT )

=item reject_process ( TEXT )

=back

=cut

sub reject_start {
    $_[0]->{_hssCfg}{EscapeFiltered}
        ? $_[0]->output_text( $_[0]->escape_html_metachars( $_[1] ) )
        : $_[0]->output_comment('<!--filtered-->');
}
*reject_end         = \&reject_start;
*reject_text        = \&reject_start;
*reject_declaration = \&reject_start;
*reject_comment     = \&reject_start;
*reject_process     = \&reject_start;

=head1 WHITELIST INITIALIZATION METHODS

The filter refers to various whitelists to determine which constructs
are acceptable.  To modify these whitelists, subclasses can override
the following methods.

Each method is called once at object initialization time, and must
return a reference to a nested data structure.  These references are
installed into the object, and used whenever the filter needs to refer
to a whitelist.

The default implementations of these methods can be invoked as class
methods.

See examples/tags/ and examples/declaration/ for examples of how to
override these methods.

=over

=item init_context_whitelist ()

Returns a reference to the C<Context> whitelist, which determines
which tags may appear at each point in the document, and which other
tags may be nested within them.

It is a hash, and the keys are context names, such as C<Flow> and
C<Inline>.

The values in the hash are hashrefs.  The keys in these subhashes are
lowercase tag names, and the values are context names, specifying the
context that the tag provides to any other tags nested within it.

The special context C<EMPTY> as a value in a subhash indicates that
nothing can be nested within that tag.

=cut

use vars qw(%_Context);

BEGIN {

    my %pre_content = ( 'br'      => 'EMPTY',
                        'span'    => 'Inline',
                        'tt'      => 'Inline',
                        'i'       => 'Inline',
                        'b'       => 'Inline',
                        'u'       => 'Inline',
                        's'       => 'Inline',
                        'strike'  => 'Inline',
                        'em'      => 'Inline',
                        'strong'  => 'Inline',
                        'dfn'     => 'Inline',
                        'code'    => 'Inline',
                        'q'       => 'Inline',
                        'samp'    => 'Inline',
                        'kbd'     => 'Inline',
                        'var'     => 'Inline',
                        'cite'    => 'Inline',
                        'abbr'    => 'Inline',
                        'acronym' => 'Inline',
                        'ins'     => 'Inline',
                        'del'     => 'Inline',
                        'a'       => 'Inline',
                        'CDATA'   => 'CDATA',
    );

    my %inline = ( %pre_content,
                   'img'   => 'EMPTY',
                   'big'   => 'Inline',
                   'small' => 'Inline',
                   'sub'   => 'Inline',
                   'sup'   => 'Inline',
                   'font'  => 'Inline',
                   'nobr'  => 'Inline',
    );

    my %flow = ( %inline,
                 'ins'        => 'Flow',
                 'del'        => 'Flow',
                 'div'        => 'Flow',
                 'p'          => 'Inline',
                 'h1'         => 'Inline',
                 'h2'         => 'Inline',
                 'h3'         => 'Inline',
                 'h4'         => 'Inline',
                 'h5'         => 'Inline',
                 'h6'         => 'Inline',
                 'ul'         => 'list',
                 'ol'         => 'list',
                 'menu'       => 'list',
                 'dir'        => 'list',
                 'dl'         => 'dt_dd',
                 'address'    => 'Inline',
                 'hr'         => 'EMPTY',
                 'pre'        => 'pre.content',
                 'blockquote' => 'Flow',
                 'center'     => 'Flow',
                 'table'      => 'table',
    );

    my %table = ( 'caption'  => 'Inline',
                  'thead'    => 'tr_only',
                  'tfoot'    => 'tr_only',
                  'tbody'    => 'tr_only',
                  'colgroup' => 'colgroup',
                  'col'      => 'EMPTY',
                  'tr'       => 'th_td',
    );

    my %head = ( 'title' => 'NoTags', );

    %_Context = ( 'Document' => { 'html' => 'Html' },
                  'Html'     => { 'head' => 'Head', 'body' => 'Flow' },
                  'Head'        => \%head,
                  'Inline'      => \%inline,
                  'Flow'        => \%flow,
                  'NoTags'      => { 'CDATA' => 'CDATA' },
                  'pre.content' => \%pre_content,
                  'table'       => \%table,
                  'list'        => { 'li' => 'Flow' },
                  'dt_dd'       => { 'dt' => 'Inline', 'dd' => 'Flow' },
                  'tr_only'  => { 'tr'  => 'th_td' },
                  'colgroup' => { 'col' => 'EMPTY' },
                  'th_td'    => { 'th'  => 'Flow', 'td' => 'Flow' },
    );
}

sub init_context_whitelist { return \%_Context; }

=item init_attrib_whitelist ()

Returns a reference to the C<Attrib> whitelist, which determines which
attributes each tag can have and the values that those attributes can
take.

It is a hash, and the keys are lowercase tag names.

The values in the hash are hashrefs.  The keys in these subhashes are
lowercase attribute names, and the values are attribute value class names,
which are short strings describing the type of values that the
attribute can take, such as C<color> or C<number>.

=cut

use vars qw(%_Attrib);

BEGIN {

    my %attr = ( 'style' => 'style' );

    my %font_attr = ( %attr,
                      'size'  => 'size',
                      'face'  => 'wordlist',
                      'color' => 'color',
    );

    my %insdel_attr = ( %attr,
                        'cite'     => 'href',
                        'datetime' => 'text',
    );

    my %texta_attr = ( %attr, 'align' => 'word', );

    my %cellha_attr = ( 'align'   => 'word',
                        'char'    => 'word',
                        'charoff' => 'size',
    );

    my %cellva_attr = ( 'valign' => 'word', );

    my %cellhv_attr = ( %attr, %cellha_attr, %cellva_attr );

    my %col_attr = ( %attr, %cellhv_attr,
                     'width' => 'size',
                     'span'  => 'number',
    );

    my %thtd_attr = ( %attr,
                      'abbr'    => 'text',
                      'axis'    => 'text',
                      'headers' => 'text',
                      'scope'   => 'word',
                      'rowspan' => 'number',
                      'colspan' => 'number',
                      %cellhv_attr,
                      'nowrap'           => 'novalue',
                      'bgcolor'          => 'color',
                      'width'            => 'size',
                      'height'           => 'size',
                      'bordercolor'      => 'color',
                      'bordercolorlight' => 'color',
                      'bordercolordark'  => 'color',
    );

    %_Attrib = ( 'br'      => { 'clear' => 'word' },
                 'em'      => \%attr,
                 'strong'  => \%attr,
                 'dfn'     => \%attr,
                 'code'    => \%attr,
                 'samp'    => \%attr,
                 'kbd'     => \%attr,
                 'var'     => \%attr,
                 'cite'    => \%attr,
                 'abbr'    => \%attr,
                 'acronym' => \%attr,
                 'q'          => { %attr, 'cite' => 'href' },
                 'blockquote' => { %attr, 'cite' => 'href' },
                 'sub'        => \%attr,
                 'sup'        => \%attr,
                 'tt'         => \%attr,
                 'i'          => \%attr,
                 'b'          => \%attr,
                 'big'        => \%attr,
                 'small'      => \%attr,
                 'u'          => \%attr,
                 's'          => \%attr,
                 'strike'     => \%attr,
                 'font'       => \%font_attr,
                 'table'      => {
                              %attr,
                              'frame' => 'word',
                              'rules' => 'word',
                              %texta_attr,
                              'bgcolor'          => 'color',
                              'background'       => 'src',
                              'width'            => 'size',
                              'height'           => 'size',
                              'cellspacing'      => 'size',
                              'cellpadding'      => 'size',
                              'border'           => 'size',
                              'bordercolor'      => 'color',
                              'bordercolorlight' => 'color',
                              'bordercolordark'  => 'color',
                              'summary'          => 'text',
                 },
                 'caption'  => { %attr, 'align' => 'word', },
                 'colgroup' => \%col_attr,
                 'col'      => \%col_attr,
                 'thead'    => \%cellhv_attr,
                 'tfoot'    => \%cellhv_attr,
                 'tbody'    => \%cellhv_attr,
                 'tr'       => {
                           %attr,
                           bgcolor => 'color',
                           %cellhv_attr,
                 },
                 'th'   => \%thtd_attr,
                 'td'   => \%thtd_attr,
                 'ins'  => \%insdel_attr,
                 'del'  => \%insdel_attr,
                 'a'    => { %attr, href => 'href', },
                 'h1'   => \%texta_attr,
                 'h2'   => \%texta_attr,
                 'h3'   => \%texta_attr,
                 'h4'   => \%texta_attr,
                 'h5'   => \%texta_attr,
                 'h6'   => \%texta_attr,
                 'p'    => \%texta_attr,
                 'div'  => \%texta_attr,
                 'span' => \%texta_attr,
                 'ul'   => {
                           %attr,
                           'type'    => 'word',
                           'compact' => 'novalue',
                 },
                 'ol' => { %attr,
                           'type'    => 'text',
                           'compact' => 'novalue',
                           'start'   => 'number',
                 },
                 'li' => { %attr,
                           'type'  => 'text',
                           'value' => 'number',
                 },
                 'dl'      => { %attr, 'compact' => 'novalue' },
                 'dt'      => \%attr,
                 'dd'      => \%attr,
                 'address' => \%attr,
                 'hr'      => {
                           %texta_attr,
                           'width'   => 'size',
                           'size'    => 'size',
                           'noshade' => 'novalue',
                 },
                 'pre'    => { %attr, 'width' => 'size' },
                 'center' => \%attr,
                 'nobr'   => {},
                 'img'    => {
                            'src'    => 'src',
                            'alt'    => 'text',
                            'width'  => 'size',
                            'height' => 'size',
                            'border' => 'size',
                            'hspace' => 'size',
                            'vspace' => 'size',
                            'align'  => 'word',
                 },
                 'body' => { 'bgcolor'    => 'color',
                             'background' => 'src',
                             'link'       => 'color',
                             'vlink'      => 'color',
                             'alink'      => 'color',
                             'text'       => 'color',
                 },
                 'head'  => {},
                 'title' => {},
                 'html'  => {},
    );
}

sub init_attrib_whitelist { return \%_Attrib; }

=item init_attval_whitelist ()

Returns a reference to the C<AttVal> whitelist, which is a hash that maps
attribute value class names from the C<Attrib> whitelist to coderefs to
subs to validate (and optionally transform) a particular attribute value.

The filter calls the attribute value validation subs with the
following parameters:

=over

=item C<filter>

A reference to the filter object.

=item C<tagname>

The lowercase name of the tag in which the attribute appears.

=item C<attrname>

The name of the attribute.

=item C<attrval>

The attribute value found in the input document, in canonical form
(see L</"CANONICAL FORM">).

=back

The validation sub can return undef to indicate that the attribute
should be removed from the tag, or it can return the new value for
the attribute, in canonical form.

=cut

use vars qw(%_AttVal);

BEGIN {
    %_AttVal = ( 'style'     => \&_hss_attval_style,
                 'size'      => \&_hss_attval_size,
                 'number'    => \&_hss_attval_number,
                 'color'     => \&_hss_attval_color,
                 'text'      => \&_hss_attval_text,
                 'word'      => \&_hss_attval_word,
                 'wordlist'  => \&_hss_attval_wordlist,
                 'wordlistq' => \&_hss_attval_wordlistq,
                 'href'      => \&_hss_attval_href,
                 'src'       => \&_hss_attval_src,
                 'stylesrc'  => \&_hss_attval_stylesrc,
                 'novalue'   => \&_hss_attval_novalue,
    );
}

sub init_attval_whitelist { return \%_AttVal; }

=item init_style_whitelist ()

Returns a reference to the C<Style> whitelist, which determines which CSS
style directives are permitted in C<style> tag attributes.  The keys are
value names such as C<color> and C<background-color>, and the values are
class names to be used as keys into the C<AttVal> whitelist.

=cut

use vars qw(%_Style);

BEGIN {
    %_Style = ( 'color'            => 'color',
                'background-color' => 'color',
                'background'       => 'stylesrc',
                'background-image' => 'stylesrc',
                'font-size'        => 'size',
                'font-family'      => 'wordlistq',
                'text-align'       => 'word',
    );
}

sub init_style_whitelist { return \%_Style; }

=item init_deinter_whitelist

Returns a reference to the C<DeInter> whitelist, which determines which inline
tags the filter should attempt to automatically de-interleave if they are
encountered interleaved.  For example, the filter will transform:

  <b>hello <i>world</b> !</i>

Into:

  <b>hello <i>world</i></b><i> !</i>

because both C<b> and C<i> appear as keys in the C<DeInter> whitelist.

=cut

use vars qw(%_DeInter);

BEGIN {
    %_DeInter = map { $_ => 1 } qw(
        tt i b big small u s strike font em strong dfn code
        q sub sup samp kbd var cite abbr acronym span
    );
}

sub init_deinter_whitelist { return \%_DeInter; }

=back

=head1 CHARACTER DATA PROCESSING

These methods transform attribute values and non-tag text from the
input document into canonical form (see L</"CANONICAL FORM">), and
transform text in canonical form into a suitable form for the output
document.

=over

=item text_to_canonical_form ( TEXT )

This method is used to reduce non-tag text from the input document to
canonical form before passing it to the filter_text() method.

The default implementation unescapes all entities that map to
C<US-ASCII> characters other than ampersand, and replaces any
ampersands that don't form part of valid entities with C<&amp;>.

=cut

sub text_to_canonical_form {
    my ( $self, $text ) = @_;

    $text =~ s#&gt;#>#g;
    $text =~ s#&lt;#<#g;
    $text =~ s#&quot;#"#g;
    $text =~ s#&apos;#'#g;

    $text =~ s! ( [^&]+ | &[a-z0-9]{2,15}; )  |
         &[#](0*[0-9]{2,6});           |
         &[#](x0*[a-f0-9]{2,6});       |
         &
       !
         defined $1 ? $1                              :
         defined $2 ? $self->_hss_decode_numeric($2) :
         defined $3 ? $self->_hss_decode_numeric($3) :
         '&amp;'
       !igex;

    return $text;
}

=item quoted_to_canonical_form ( VALUE )

This method is used to reduce attribute values quoted with doublequotes
or singlequotes to canonical form before passing it to the handler subs
in the C<AttVal> whitelist.

The default behavior is the same as that of C<text_to_canonical_form()>,
plus it converts any CR, LF or TAB characters to spaces.

=cut

sub quoted_to_canonical_form {
    my ( $self, $text ) = @_;
    $text = $self->text_to_canonical_form($text);
    $text =~ tr/\n\r\t/   /s;
    return $text;
}

=item unquoted_to_canonical_form ( VALUE )

This method is used to reduce attribute values without quotes to
canonical form before passing it to the handler subs in the C<AttVal>
whitelist.

The default implementation simply replaces all ampersands with C<&amp;>,
since that corresponds with the way most browsers treat entities in
unquoted values.

=cut

sub unquoted_to_canonical_form {
    my ( $self, $text ) = @_;

    $text =~ s#&#&amp;#g;
    return $text;
}

=item canonical_form_to_text ( TEXT )

This method is used to convert the text in canonical form returned by
the filter_text() method to a form suitable for inclusion in the output
document.

The default implementation runs anything that doesn't look like a
valid entity through the escape_html_metachars() method.

=cut

sub canonical_form_to_text {
    my ( $self, $text ) = @_;
    $text =~ s/ (&[#\w]+;) | (.[^&]*)
              / defined $1 ? $1 : $self->escape_html_metachars($2)
              /gex;

    return $text;
}

=item canonical_form_to_attval ( ATTVAL )

This method is used to convert the text in canonical form returned by
the C<AttVal> handler subs to a form suitable for inclusion in
doublequotes in the output tag.

The default implementation converts CR, LF and TAB characters to a single
space, and runs anything that doesn't look like a
valid entity through the escape_html_metachars() method.

=cut

sub canonical_form_to_attval {
    my ( $self, $text ) = @_;
    $text =~ tr/\n\r\t/   /s;
    return $self->canonical_form_to_text($text);
}

=item validate_href_attribute ( TEXT )

If the C<AllowHref> filter configuration option is set, then this
method is used to validate C<href> type attribute values.  TEXT is
the attribute value in canonical form.  Returns a possibly modified
attribute value (in canonical form) or C<undef> to reject the attribute.

The default implementation allows only absolute C<http> and C<https>
URLs, permits port numbers and query strings, and imposes reasonable
length limits.

It does not URI escape the query string, and it does not guarantee
properly formatted URIs, it just tries to give safe URIs. You can
always use an attribute callback (see L<"Attribute Callbacks">)
to provide stricter handling.

=cut

sub validate_href_attribute {
    my ( $self, $text ) = @_;

    return $1
        if $self->{_hssCfg}{AllowRelURL}
        and $text =~ /^((?:[\w\-.!~*|;\/?=+\$,%#]|&amp;){0,100})$/;

    $text =~ m< ^ ( https? :// [\w\-\.]{1,100} (?:\:\d{1,5})?
                    (?: / (?:[\w\-.!~*|;/?=+\$,%#]|&amp;){0,100} )?
                  )
                $
              >x ? $1 : undef;
}

=item validate_mailto ( TEXT )

If the C<AllowMailto> filter configuration option is set, then this
method is used to validate C<href> type attribute values which begin
with C<mailto:>.  TEXT is the attribute value in canonical form.
Returns a possibly modified attribute value (in canonical form) or C<undef>
to reject the attribute.

This uses a lightweight regex and does not guarantee that email
addresses are properly formatted. You can
always use an attribute callback (see L<"Attribute Callbacks">)
to provide stricter handling.

=cut

sub validate_mailto {
    my ( $self, $text ) = @_;

    return $1
        if $text =~ m/^(
            mailto:[\w\-!#$%&'*+-\/=?^_`{|}~.]{1,64}    # localpart
            \@                                          # @
            [\w\-\.]{1,100}                             # domain
            (?:                                         # opt query string
                \?
                (?:[\w\-.!~*|;\/?=+\$,%#]|&amp;){0,100}
            )?
            )$/x;
    return;
}

=item validate_src_attribute ( TEXT )

If the C<AllowSrc> filter configuration option is set, then this
method is used to validate C<src> type attribute values.  TEXT is
the attribute value in canonical form.  Returns a possibly modified
attribute value (in canonical form) or C<undef> to reject the attribute.

The default implementation behaves as validate_href_attribute().

=cut

*validate_src_attribute = \&validate_href_attribute;

=back

=head1 OTHER METHODS TO OVERRIDE

As well as the output, reject, init and cdata methods listed above,
it might make sense for subclasses to override the following methods:

=over

=item filter_text ( TEXT )

This method will be invoked to filter blocks of non-tag text in the
input document.  Both input and output are in canonical form, see
L</"CANONICAL FORM">.

The default implementation does no filtering.

=cut

sub filter_text {
    my ( $self, $text ) = @_;

    return $text;
}

=item escape_html_metachars ( TEXT )

This method is used to escape all HTML metacharacters in TEXT.
The return value must be a copy of TEXT with metacharacters escaped.

The default implementation escapes a minimal set of
metacharacters for security against XSS vulnerabilities.  The set
of characters to escape is a compromise between the need for
security and the need to ensure that the filter will work for
documents in as many different character sets as possible.

Subclasses which make strong assumptions about the document
character set will be able to escape much more aggressively.

=cut

use vars qw(%_Escape_HTML_map);

BEGIN {
    %_Escape_HTML_map = ( '&' => '&amp;',
                          '<' => '&lt;',
                          '>' => '&gt;',
                          '"' => '&quot;',
                          "'" => '&#39;',
    );
}

sub escape_html_metachars {
    my ( $self, $text ) = @_;

    $text =~ s#([&<>"'])# $_Escape_HTML_map{$1} #ge;
    return $text;
}

=item strip_nonprintable ( TEXT )

Returns a copy of TEXT with runs of nonprintable characters replaced
with spaces or some other harmless string.  Avoids replacing anything
with the empty string, as that can lead to other security issues.

The default implementation strips out only NULL characters, in order to
avoid scrambling text for as many different character sets as possible.

Subclasses which make some sort of assumption about the character set
in use will be able to have a much wider definition of a nonprintable
character, and hence a more secure strip_nonprintable() implementation.

=cut

sub strip_nonprintable {
    my ( $self, $text ) = @_;

    $text =~ tr#\0# #s;
    return $text;
}

=back

=head1 ATTRIBUTE VALUE HANDLER SUBS

References to the following subs appear in the C<AttVal> whitelist
returned by the init_attval_whitelist() method.

=over

=item _hss_attval_style( FILTER, TAGNAME, ATTRNAME, ATTRVAL )

Attribute value hander for the C<style> attribute.

=cut

sub _hss_attval_style {
    my ( $filter, $tagname, $attrname, $attrval ) = @_;
    my @clean = ();

    # Split on semicolon, making a reasonable attempt to ignore
    # semicolons inside doublequotes or singlequotes.
    while ( $attrval =~ s{^((?:[^;'"]|'[^']*'|"[^"]*")+)}{} ) {
        my $elt = $1;
        $attrval =~ s/^;//;

        if ( $elt =~ m|^\s*([\w\-]+)\s*:\s*(.+?)\s*$|s ) {
            my ( $key, $val ) = ( lc $1, $2 );

            my $value_class = $filter->{_hssStyle}{$key};
            next unless defined $value_class;
            my $sub = $filter->{_hssAttVal}{$value_class};
            next unless defined $sub;

            my $cleanval = &{$sub}( $filter, 'style-psuedo-tag', $key, $val );
            if ( defined $cleanval ) {
                push @clean, "$key:$val";
            }
        }
    }

    return join '; ', @clean;
}

=item _hss_attval_size ( FILTER, TAGNAME, ATTRNAME, ATTRVAL )

Attribute value handler for attributes who's values are some sort of
size or length.

=cut

sub _hss_attval_size {
    $_[3]
        =~ /^\s*([+-]?\d{1,20}(?:\.\d{1,20)?)\s*((?:\%|\*|ex|px|pc|cm|mm|in|pt|em)?)\s*$/i
        ? lc "$1$2"
        : undef;
}

=item _hss_attval_number ( FILTER, TAGNAME, ATTRNAME, ATTRVAL )

Attribute value handler for attributes who's values are a simple
integer.

=cut

sub _hss_attval_number {
    $_[3] =~ /^\s*\+?(\d{1,20})\s*$/ ? $1 : undef;
}

=item _hss_attval_color ( FILTER, TAGNAME, ATTRNAME, ATTRVAL )

Attribute value handler for color attributes.

=cut

sub _hss_attval_color {
    $_[3] =~ /^\s*(\w{2,20}|#[\da-fA-F]{6})\s*$/ ? $1 : undef;
}

=item _hss_attval_text ( FILTER, TAGNAME, ATTRNAME, ATTRVAL )

Attribute value handler for text attributes.

=cut

sub _hss_attval_text {
    length $_[3] <= 200 ? $_[3] : undef;
}

=item _hss_attval_word ( FILTER, TAGNAME, ATTRNAME, ATTRVAL )

Attribute value handler for attributes who's values must consist of
a single short word, with minus characters permitted.

=cut

sub _hss_attval_word {
    $_[3] =~ /^\s*([\w\-]{1,30})\s*$/ ? $1 : undef;
}

=item _hss_attval_wordlist ( FILTER, TAGNAME, ATTRNAME, ATTRVAL )

Attribute value handler for attributes who's values must consist of
one or more words, separated by spaces and/or commas.

=cut

sub _hss_attval_wordlist {
    $_[3] =~ /^\s*([\w\-\, ]{1,200})\s*$/ ? $1 : undef;
}

=item _hss_attval_wordlistq ( FILTER, TAGNAME, ATTRNAME, ATTRVAL )

Attribute value handler for attributes who's values must consist of
one or more words, separated by commas, with optional doublequotes
around words and spaces allowed within the doublequotes.

=cut

sub _hss_attval_wordlistq {
    my ( $filter, $tagname, $attrname, $attrval ) = @_;

    my @words = grep {/^\s*(?:(?:"[\w\- ]{1,50}")|(?:[\w\-]{1,30}))\s*$/}
        split /,/, $attrval;

    scalar(@words) ? join( ', ', @words ) : undef;
}

=item _hss_attval_href ( FILTER, TAGNAME, ATTRNAME, ATTRVAL )

Attribute value handler for C<href> type attributes.  If the C<AllowHref>
or C<AllowMailto> configuration options are set,
uses the validate_href_attribute() method to check the attribute value.

=cut

sub _hss_attval_href {
    my ( $filter, $tagname, $attname, $attval ) = @_;

    if ( $filter->{_hssCfg}{AllowMailto}
         && substr( $attval, 0, 7 ) eq 'mailto:' )
    {
        return $filter->validate_mailto($attval);
    }
    elsif ( $filter->{_hssCfg}{AllowHref} ) {
        return $filter->validate_href_attribute($attval);
    }
    return;

}

=item _hss_attval_src ( FILTER, TAGNAME, ATTRNAME, ATTRVAL )

Attribute value handler for C<src> type attributes.  If the C<AllowSrc>
configuration option is set, uses the validate_src_attribute() method
to check the attribute value.

=cut

sub _hss_attval_src {
    my ( $filter, $tagname, $attname, $attval ) = @_;

    if ( $filter->{_hssCfg}{AllowSrc} ) {
        return $filter->validate_src_attribute($attval);
    }
    else {
        return;
    }
}

=item _hss_attval_stylesrc ( FILTER, TAGNAME, ATTRNAME, ATTRVAL )

Attribute value handler for C<src> type style pseudo attributes.

=cut

sub _hss_attval_stylesrc {
    my ( $filter, $tagname, $attname, $attval ) = @_;

    if ( $attval =~ m#^\s*url\((.+)\)\s*$# ) {
        return _hss_attval_src( $filter, $tagname, $attname, $1 );
    }
    else {
        return;
    }
}

=item _hss_attval_novalue ( FILTER, TAGNAME, ATTRNAME, ATTRVAL )

Attribute value handler for attributes that have no value or a value that
is ignored.  Just returns the attribute name as the value.

=cut

sub _hss_attval_novalue {
    my ( $filter, $tagname, $attname, $attval ) = @_;

    return $attname;
}

=back

=head1 CANONICAL FORM

Many of the methods described above deal with text from the input
document, encoded in what I call C<canonical form>, defined as
follows:

All characters other than ampersands represent themselves.  Literal
ampersands are encoded as C<&amp;>.  Non C<US-ASCII> characters
may appear as literals in whatever character set is in use, or they
may appear as named or numeric HTML entities such as C<&aelig;>,
C<&#31337;> and C<&#xFF;>.  Unknown named entities such as C<&foo;>
may appear.

The idea is to be able to be able to reduce input text to a minimal
form, without making too many assumptions about the character set in
use.

=head1 PRIVATE METHODS

The following methods are internal to this class, and should not be
invoked from elsewhere.  Subclasses should not use or override
these methods.

=over

=item _hss_prepare_ban_list (CFG)

Returns a hash ref representing all the banned tags, based on the values
of BanList and BanAllBut

=cut

#===================================
sub _hss_prepare_ban_list {
#===================================
    my ( $self, $cfg ) = @_;

    my $ban_list = $cfg->{BanList} || {};
    my $prepared_ban_list
        = ref $ban_list eq 'ARRAY'
        ? { map { $_ => 1 } @$ban_list }
        : $ban_list;

    # Rules => {'*' => 0} or {'*' => {tag => '0'}} means BanAllBut other tags
    # mentioned in the rules
    if ( my $rules = $cfg->{Rules} ) {
        if ( exists $rules->{'*'}
             && ( (    ref $rules->{'*'} eq 'HASH'
                    && exists $rules->{'*'}{'tag'}
                    && !$rules->{'*'}{'tag'}
                  )
                  || ( !$rules->{'*'} )
             )
            )
        {
            $cfg->{BanAllBut} ||= [];

        }
    }

    if ( $cfg->{BanAllBut} ) {
        my %ban = map { $_ => 1 } keys %{ $self->{_hssAttrib} };
        foreach my $dontban ( @{ $cfg->{BanAllBut} } ) {
            delete $ban{$dontban} unless $prepared_ban_list->{$dontban};
        }
        $prepared_ban_list = \%ban;
    }
    return $prepared_ban_list;
}

=item _hss_prepare_rules (CFG)

Returns a hash ref representing the tag and attribute rules (See L</"Rules">).

Returns undef if no filters are specified, in which case the
attribute filter code has very little performance impact. If any rules are
specified, then every tag and attribute is checked.

=cut

#===================================
sub _hss_prepare_rules {
#===================================
    my ( $self, $cfg ) = @_;

    my $rules = $cfg->{Rules};

    return
        unless $rules
        && ref $rules eq 'HASH'
        && keys %$rules;

    die "'Rules' must be a HASH ref"
        unless ref $rules eq 'HASH';

    my $banned = $self->{_hssBanList};

    my %prepared_rules;
    foreach my $tag ( keys %$rules ) {
        my $rule = $rules->{$tag};
        $tag = lc($tag);

        # TAG => 0
        if ( !$rule ) {
            $banned->{$tag} ||= 1;
            next;
        }

        delete $banned->{$tag};
        if ( my $rule_ref = ref $rule ) {

            # TAG => CODEREF
            $rule = { tag => $rule }
                if $rule_ref eq 'CODE';

            die "Unknown value for tag '$tag'. Must be a HASH or a CODE ref"
                unless ref $rule eq 'HASH';
        }
        else {

            # TAG => 1
            next;
        }

        # TAG => HASHREF
        my %prepared_rule;

        # Required attributes
        if ( my $required = delete $rule->{required} ) {
            if ( ref $required eq 'ARRAY' && @$required ) {
                $prepared_rule{required} = $required;
            }
        }

    RULE:
        while ( my ( $key, $value ) = each %$rule ) {

            $key = lc($key);

            # Pass through code refs
            my $ref_type = ref $value;
            if ( $ref_type eq 'CODE' ) {
                $prepared_rule{$key} = $value;
                next RULE;
            }

            if ( !$ref_type ) {

                # Pass through 1 / 0
                if ( $value eq '0' or $value eq '1' ) {
                    $prepared_rule{$key} = $value;
                    next RULE;
                }

                # Any remaining values must be regexes
                $value = eval {qr/$value/}
                    or die "Invalid regex rule for '$tag' => '$key' : $@";
                $ref_type = 'Regexp';
            }

            die "Invalid rule value for '$tag' => '$key' : $ref_type"
                unless $ref_type eq 'Regexp';

            # Convert regex into anonymous sub
            $prepared_rule{$key} = sub {
                my ( $rule, $tagname, $attname, $attval ) = @_;
                return $attval =~ m/$value/
                    ? $attval
                    : undef;
            };

        }
        $prepared_rules{$tag} = \%prepared_rule
            if keys %prepared_rule;
    }
    return
        unless keys %prepared_rules;

    # Add default setting of {'*' => {'*' => 1}}
    # unless it already has a value
    unless ( exists $prepared_rules{'*'}{'*'} ) {
        $prepared_rules{'*'}{'*'} = 1;
    }

    # Remove required attribs from default
    delete $prepared_rules{'*'}{required};

    # Remove 'tag' from default unless is a sub
    delete $prepared_rules{'*'}{tag} unless ref $prepared_rules{'*'}{tag};
    return \%prepared_rules;
}

=item _hss_get_attr_filter ( DEFAULT_FILTERS TAG_FILTERS ATTR_NAME)

Returns the attribute filter rule to apply to this particular attribute.

Checks for:

  - a named attribute rule in a named tag
  - a default * attribute rule in a named tag
  - a named attribute rule in the default * rules
  - a default * attribute rule in the default * rules

=cut

sub _hss_get_attr_filter {
    my ( $self, $default_filters, $tag_filters, $key ) = @_;

    return $tag_filters->{$key}
        if exists $tag_filters->{$key};

    return $tag_filters->{'*'}
        if exists $tag_filters->{'*'};

    return $default_filters->{$key}
        if exists $default_filters->{$key};

    return $default_filters->{'*'};

}

=item _hss_join_attribs (FILTERED_ATTRIBS)

Accepts a hash ref containing the attribute names as the keys, and the attribute
values as the values.  Escapes them and returns a string ready for output to
HTML

=cut

sub _hss_join_attribs {
    my ( $self, $attrs ) = @_;
    my $filtered_attrs = '';
    foreach my $key ( sort keys %$attrs ) {
        my $escaped = $self->canonical_form_to_attval( $attrs->{$key} );
        $filtered_attrs .= qq| $key="$escaped"|;

    }
    return $filtered_attrs;
}

=item _hss_decode_numeric ( NUMERIC )

Returns the string that should replace the numeric entity NUMERIC
in the text_to_canonical_form() method.

=cut

sub _hss_decode_numeric {
    my ( $self, $numeric ) = @_;

    my $hex = ( $numeric =~ s/^x//i ? 1 : 0 );

    $numeric =~ s/^0+//;
    my $number = ( $hex ? hex($numeric) : $numeric );

    if ( $number == ord '&' ) {
        return '&amp;';
    }
    elsif ( $number < 127 ) {
        return chr $number;
    }
    else {
        return '&#' . ( $hex ? 'x' : '' ) . uc($numeric) . ';';
    }
}

=item _hss_tag_is_banned ( TAGNAME )

Returns true if the lower case tag name TAGNAME is on the list of
harmless tags that the filter is configured to block, false otherwise.

=cut

sub _hss_tag_is_banned {
    my ( $self, $tag ) = @_;

    exists $self->{_hssBanList}{$tag} ? 1 : 0;
}

=item _hss_get_to_valid_context ( TAG )

Tries to get the filter to a context in which the tag TAG is
allowed, by introducing extra end tags or start tags if
necessary.  TAG can be either the lower case name of a tag or
the string 'CDATA'.

Returns 1 if an allowed context is reached, or 0 if there's no
reasonable way to get to an allowed context and the tag should
just be rejected.

=cut

sub _hss_get_to_valid_context {
    my ( $self, $tag ) = @_;

    # Special case: nested <a> is never valid.
    if ( $tag eq 'a' ) {
        foreach my $ancestor ( @{ $self->{_hssStack} } ) {
            return 0 if $ancestor->{NAME} eq 'a';
        }
    }

    return 1 if $self->_hss_valid_in_current_context($tag);

    if ( $self->_hss_context eq 'Document' ) {
        $self->input_start('<html>');
        return 1 if $self->_hss_valid_in_current_context($tag);
    }

    if (     $self->_hss_context eq 'Html'
         and $self->_hss_valid_in_context( $tag, 'Flow' ) )
    {
        $self->input_start('<body>');
        return 1;
    }

    return 0
        unless grep { $self->_hss_valid_in_context( $tag, $_->{CTX} ) }
        @{ $self->{_hssStack} };

    until ( $self->_hss_valid_in_current_context($tag) ) {
        $self->_hss_close_innermost_tag;
    }

    return 1;
}

=item _hss_close_innermost_tag ()

Closes the innermost open tag.

=cut

sub _hss_close_innermost_tag {
    my ($self) = @_;
    $self->output_stack_entry( shift @{ $self->{_hssStack} } );
    die 'tag stack underflow' unless scalar @{ $self->{_hssStack} };
}

=item _hss_context ()

Returns the current named context of the filter.

=cut

sub _hss_context {
    my ($self) = @_;

    $self->{_hssStack}[0]{CTX};
}

=item _hss_valid_in_context ( TAG, CONTEXT )

Returns true if the lowercase tag name TAG is valid in context
CONTEXT, false otherwise.

=cut

sub _hss_valid_in_context {
    my ( $self, $tag, $context ) = @_;

    $self->{_hssContext}{$context}{$tag} ? 1 : 0;
}

=item _hss_valid_in_current_context ( TAG )

Returns true if the lowercase tag name TAG is valid in the filter's
current context, false otherwise.

=cut

sub _hss_valid_in_current_context {
    my ( $self, $tag ) = @_;

    $self->_hss_valid_in_context( $tag, $self->_hss_context );
}

=back

=head1 BUGS AND LIMITATIONS

=over

=item Performance

This module does a lot of work to ensure that tags are correctly
nested and are not left open, causing unnecessary overhead for
applications where that doesn't matter.

Such applications may benefit from using the more lightweight
L<HTML::Scrubber::StripScripts> module instead.

=item Strictness

URIs and email addresses are cleaned up to be safe, but not
necessarily accurate.  That would have required adding dependencies.
Attribute callbacks can be used to add this functionality if required,
or the validation methods can be overriden.

By default, filtered HTML may not be valid strict XHTML, for instance empty
required attributes may be outputted.  However, with L</"Rules">,
it should be possible to force the HTML to validate.

=item REPORTING BUGS

Please report any bugs or feature requests to
bug-html-stripscripts@rt.cpan.org, or through the web interface at
L<http://rt.cpan.org>.

=back

=head1 SEE ALSO

L<HTML::Parser>, L<HTML::StripScripts::Parser>,
L<HTML::StripScripts::Regex>

=head1 AUTHOR

Original author Nick Cleaton E<lt>nick@cleaton.netE<gt>

New code added and module maintained by Clinton Gormley
E<lt>clint@traveljury.comE<gt>

=head1 COPYRIGHT

Copyright (C) 2003 Nick Cleaton.  All Rights Reserved.

Copyright (C) 2007 Clinton Gormley.  All Rights Reserved.

=head1 LICENSE

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;

