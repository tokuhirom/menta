package HTML::FillInForm;

use integer; # no floating point math so far!
use strict; # and no funny business, either.

use Carp; # generate better errors with more context

# required for attr_encoded
use HTML::Parser 3.26;

# required for UNIVERSAL->can
require 5.005;

use vars qw($VERSION @ISA);
$VERSION = '2.00';

@ISA = qw(HTML::Parser);

sub new {
  my ($class) = @_;
  my $self = bless {}, $class;
  $self->init;
  # tell HTML::Parser not to decode attributes
  $self->attr_encoded(1);
  return $self;
}

# a few shortcuts to fill()
sub fill_file      { my $self = shift; return $self->fill('file'     ,@_); }
sub fill_arrayref  { my $self = shift; return $self->fill('arrayref' ,@_); }
sub fill_scalarref { my $self = shift; return $self->fill('scalarref',@_); }

# track the keys we support. Useful for file-name detection.
sub _known_keys {
    return {
        scalarref      =>  1,
        arrayref       =>  1,
        fdat           =>  1,
        fobject        =>  1,
        file           =>  1,
        target         =>  1,
        fill_password  =>  1,
        ignore_fields  =>  1,
        disable_fields =>  1,
    }
}

sub fill {
   my $self = shift;

  # If we are called as a class method, go ahead and call new().
  $self = $self->new if (not ref $self);

  my %option;

  # If the first arg is a scalarref, translate that to scalarref => $first_arg
  if (ref $_[0] eq 'SCALAR') {
      $option{scalarref} = shift;
  }
  elsif (ref $_[0] eq 'ARRAY') {
      $option{arrayref} = shift;
  }
  elsif (ref $_[0] eq 'GLOB') {
      $option{file} = shift;
  }
  elsif (ref $_[0]) {
    croak "data source is not a reference type we understand";
  }
  # Last chance, if the first arg isn't one of the known keys, we 
  # assume it is a file name.
  elsif (not _known_keys()->{$_[0]} )  {
    $option{file} =  shift;
  }
  else {
      # Should be a known key. Nothing to do.
  }


  # Now, check to see if the next arg is also a reference. 
  my $data;
  if (ref $_[0]) {
      $data = shift;
      $data = [$data] unless ref $data eq 'ARRAY';

      for my $source (@$data) {
          if (ref $source eq 'HASH') {
              push @{ $option{fdat} }, $source;
          }
          elsif (ref $source) {
              if ($source->can('param')) {
                  push @{ $option{fobject} }, $source;
              }
              else {
                  croak "data source $source does not supply a param method";
              }
          }
          elsif (defined $source) {
              croak "data source $source is not a hash or object reference";
          }
      }

  }

 
  # load in the rest of the options
  %option = (%option, @_);


  # As suggested in the docs, merge multiple fdats into one. 
  if (ref $option{fdat} eq 'ARRAY') {
      my %merged;
      for my $hash (@{ $option{fdat} }) {
          for my $key (keys %$hash) {
              $merged{$key} = $hash->{$key};
          }
      }
      $option{'fdat'} = \%merged;
  }


  my %ignore_fields;
  %ignore_fields = map { $_ => 1 } ( ref $option{'ignore_fields'} eq 'ARRAY' )
    ? @{ $option{ignore_fields} } : $option{ignore_fields} if exists( $option{ignore_fields} );
  $self->{ignore_fields} = \%ignore_fields;

  my %disable_fields;
  %disable_fields = map { $_ => 1 } ( ref $option{'disable_fields'} eq 'ARRAY' )
    ? @{ $option{disable_fields} } : $option{disable_fields} if exists( $option{disable_fields} );
  $self->{disable_fields} = \%disable_fields;

  if (my $fdat = $option{fdat}){
    # Copy the structure to prevent side-effects.
    my %copy;
    keys %$fdat; # reset fdat if each or Dumper was called on fdat
    while(my($key, $val) = each %$fdat) {
      next if exists $ignore_fields{$key};
      $copy{ $key } = ref $val eq 'ARRAY' ? [ @$val ] : $val;
    }
    $self->{fdat} = \%copy;
  }

  # We want the reference to these objects to go out of scope at the
  # end of the method.
  local $self->{objects} = [];
  if(my $objects = $option{fobject}){
    unless(ref($objects) eq 'ARRAY'){
      $objects = [ $objects ];
    }
    for my $object (@$objects){
      # make sure objects in 'param_object' parameter support param()
      defined($object->can('param')) or
	croak("HTML::FillInForm->fill called with fobject option, containing object of type " . ref($object) . " which lacks a param() method!");
    }

    $self->{objects} = $objects;
  }
  if (my $target = $option{target}){
    $self->{'target'} = $target;
  }

  if (defined($option{fill_password})){
    $self->{fill_password} = $option{fill_password};
  } else {
    $self->{fill_password} = 1;
  }

  # make sure method has data to fill in HTML form with!
  unless(exists $self->{fdat} || $self->{objects}){
    croak("HTML::FillInForm->fillInForm() called without 'fobject' or 'fdat' parameter set");
  }

  local $self->{object_param_cache};

  if(my $file = $option{file}){
    $self->parse_file($file);
  } elsif (my $scalarref = $option{scalarref}){
    $self->parse($$scalarref);
  } elsif (my $arrayref = $option{arrayref}){
    for (@$arrayref){
      $self->parse($_);
    }
  }

  $self->eof;
  return delete $self->{output};
}

# handles opening HTML tags such as <input ...>
sub start {
  my ($self, $tagname, $attr, $attrseq, $origtext) = @_;

  # set the current form
  if ($tagname eq 'form') {
    $self->{object_param_cache} = {};
    if (exists $attr->{'name'} || exists $attr->{'id'}) {
      $self->{'current_form'} = $attr->{'name'} || $attr->{'id'};
    } else {
      # in case of previous one without </FORM>
      delete $self->{'current_form'};
    }
  }

  # This form is not my target.
  if (exists $self->{'target'} &&
      (! exists $self->{'current_form'} ||
       $self->{'current_form'} ne $self->{'target'})) {
    $self->{'output'} .= $origtext;
    return;
  }
  
  # HTML::Parser converts tagname to lowercase, so we don't need /i
  if ($self->{option_no_value}) {
    $self->{output} .= '>';
    delete $self->{option_no_value};
  }

  # Check if we need to disable  this field
  $attr->{disable} = 1
    if exists $attr->{'name'} and
    exists $self->{disable_fields}{ $attr->{'name'} } and
    $self->{disable_fields}{ $attr->{'name'} } and
    not ( exists $attr->{disable} and $attr->{disable} );
  if ($tagname eq 'input'){
    my $value = exists $attr->{'name'} ? $self->_get_param($attr->{'name'}) : undef;
    # force hidden fields to have a value
    $value = '' if exists($attr->{'type'}) && $attr->{'type'} eq 'hidden' && ! exists $attr->{'value'} && ! defined $value;
    if (defined($value)){
      $value = $self->escapeHTMLStringOrList($value);
      # check for input type, noting that default type is text
      if (!exists $attr->{'type'} ||
	  $attr->{'type'} =~ /^(text|textfield|hidden|)$/i){
	if ( ref($value) eq 'ARRAY' ) {
	  $value = shift @$value;
	  $value = '' unless defined $value;
        }
	$attr->{'value'} = $value;
      } elsif (lc $attr->{'type'} eq 'password' && $self->{fill_password}) {
	if ( ref($value) eq 'ARRAY' ) {
	  $value = shift @$value;
	  $value = '' unless defined $value;
        }
	$attr->{'value'} = $value;
      } elsif (lc $attr->{'type'} eq 'radio'){
	if ( ref($value) eq 'ARRAY' ) {
	  $value = $value->[0];
	  $value = '' unless defined $value;
        }
	# value for radio boxes default to 'on', works with netscape
	$attr->{'value'} = 'on' unless exists $attr->{'value'};
	if ($attr->{'value'} eq $value){
	  $attr->{'checked'} = 'checked';
	} else {
	  delete $attr->{'checked'};
	}
      } elsif (lc $attr->{'type'} eq 'checkbox'){
	# value for checkboxes default to 'on', works with netscape
	$attr->{'value'} = 'on' unless exists $attr->{'value'};

	delete $attr->{'checked'}; # Everything is unchecked to start
        $value = [ $value ] unless ref($value) eq 'ARRAY';
	foreach my $v ( @$value ) {
	  if ( $attr->{'value'} eq $v ) {
	    $attr->{'checked'} = 'checked';
	  }
	}
#      } else {
#	warn(qq(Input field of unknown type "$attr->{type}": $origtext));
      }
    }
    $self->{output} .= "<$tagname";
    while (my ($key, $value) = each %$attr) {
      next if $key eq '/';
      $self->{output} .= sprintf qq( %s="%s"), $key, $value;
    }
    # extra space put here to work around Opera 6.01/6.02 bug
    $self->{output} .= ' /' if $attr->{'/'};
    $self->{output} .= ">";
  } elsif ($tagname eq 'option'){
    my $value = $self->_get_param($self->{selectName});
    $value = [ $value ] unless ( ref($value) eq 'ARRAY' );

    if ( defined $value->[0] ){
      $value = $self->escapeHTMLStringOrList($value);
      delete $attr->{selected} if exists $attr->{selected};
      
      if(defined($attr->{'value'})){
        # option tag has value attr - <OPTION VALUE="foo">bar</OPTION>
        
        if ($self->{selectMultiple}){
          # check if the option tag belongs to a multiple option select
	  foreach my $v ( grep { defined } @$value ) {
	    if ( $attr->{'value'} eq $v ){
	      $attr->{selected} = 'selected';
	    }
          }
        } else {
          # if not every value of a fdat ARRAY belongs to a different select tag
          if (not $self->{selectSelected}){
	    if ( $attr->{'value'} eq $value->[0]){
	      shift @$value if ref($value) eq 'ARRAY';
	      $attr->{selected} = 'selected';
              $self->{selectSelected} = 1; # remeber that an option tag is selected for this select tag
	    }
          }
        }
      } else {
        # option tag has no value attr - <OPTION>bar</OPTION>
	# save for processing under text handler
	$self->{option_no_value} = $value;
      }
    }
    $self->{output} .= "<$tagname";
    while (my ($key, $value) = each %$attr) {
      $self->{output} .= sprintf qq( %s="%s"), $key, $value;
    }
    unless ($self->{option_no_value}){
      # we can close option tag here
      $self->{output} .= ">";
    }
  } elsif ($tagname eq 'textarea'){
    if ($attr->{'name'} and defined (my $value = $self->_get_param($attr->{'name'}))){
      $value = $self->escapeHTMLStringOrList($value);
      $value = (shift @$value || '') if ref($value) eq 'ARRAY';
      # <textarea> foobar </textarea> -> <textarea> $value </textarea>
      # we need to set outputText to 'no' so that 'foobar' won't be printed
      $self->{outputText} = 'no';
      $self->{output} .= $origtext . $value;
    } else {
      $self->{output} .= $origtext;
    }
  } elsif ($tagname eq 'select'){
    $self->{selectName} = $attr->{'name'};
    if (defined $attr->{'multiple'}){
      $self->{selectMultiple} = 1; # helper var to remember if the select tag has the multiple attr set or not
    } else {
      $self->{selectMultiple} = 0;
      $self->{selectSelected} = 0; # helper var to remember if an option was already selected in the current select tag
    }
    $self->{output} .= $origtext;
  } else {
    $self->{output} .= $origtext;
  }
}

sub _get_param {
  my ($self, $param) = @_;

  return undef if $self->{ignore_fields}{$param};

  return $self->{fdat}{$param} if exists $self->{fdat}{$param};

  return $self->{object_param_cache}{$param} if exists $self->{object_param_cache}{$param};

  # traverse the list in reverse order for backwards compatibility
  # with the previous implementation.
  for my $o (reverse @{$self->{objects}}) {
    my @v = $o->param($param);

    next unless @v;

    return $self->{object_param_cache}{$param} = @v > 1 ? \@v : $v[0];
  }

  return undef;
}

# handles non-html text
sub text {
  my ($self, $origtext) = @_;
  # just output text, unless replaced value of <textarea> tag
  unless(exists $self->{outputText} && $self->{outputText} eq 'no'){
    if(exists $self->{option_no_value}){
      # dealing with option tag with no value - <OPTION>bar</OPTION>
      my $values = $self->{option_no_value};
      my $value = $origtext;
      $value =~ s/^\s+//;
      $value =~ s/\s+$//;
      foreach my $v ( @$values ) {
	if ( $value eq $v ) {
	  $self->{output} .= ' selected="selected"';
        }
      }
      # close <OPTION> tag
      $self->{output} .= ">$origtext";
      delete $self->{option_no_value};
    } else {
      $self->{output} .= $origtext;
    }
  }
}

# handles closing HTML tags such as </textarea>
sub end {
  my ($self, $tagname, $origtext) = @_;
  if ($self->{option_no_value}) {
    $self->{output} .= '>';
    delete $self->{option_no_value};
  }
  if($tagname eq 'select'){
    delete $self->{selectName};
  } elsif ($tagname eq 'textarea'){
    delete $self->{outputText};
  } elsif ($tagname eq 'form') {
    delete $self->{'current_form'};
  }
  $self->{output} .= $origtext;
}

sub escapeHTMLStringOrList {
  my ($self, $toencode) = @_;

  if (ref($toencode) eq 'ARRAY') {
    foreach my $elem (@$toencode) {
      $elem = $self->escapeHTML($elem);
    }
    return $toencode;
  } else {
    return $self->escapeHTML($toencode);
  }
}

sub escapeHTML {
  my ($self, $toencode) = @_;

  return undef unless defined($toencode);
  $toencode =~ s/&/&amp;/g;
  $toencode =~ s/\"/&quot;/g;
  $toencode =~ s/>/&gt;/g;
  $toencode =~ s/</&lt;/g;
  return $toencode;
}

sub comment {
    my ( $self, $text ) = @_;
    # if it begins with '[if ' and doesn't end with '<![endif]'
    # it's a "downlevel-revealed" conditional comment (stupid IE)
    # or
    # if it ends with '[endif]' then it's the end of a
    # "downlevel-revealed" conditional comment
    if(
        (
            ( index($text, '[if ') == 0 )
            &&
            ( $text !~ /<!\[endif\]$/ )
        )
        ||
        ( $text eq '[endif]' )
    ) {
        $self->{output} .= '<!' . $text . '>';
    } else {
        $self->{output} .= '<!--' . $text . '-->';
    }
}

sub process {
  my ( $self, $token0, $text ) = @_;
  $self->{output} .= $text;
}

sub declaration {
  my ( $self, $text ) = @_;
  $self->{output} .= '<!' . $text . '>';
}

1;

__END__

=head1 NAME

HTML::FillInForm - Populates HTML Forms with data.

=head1 DESCRIPTION

This module fills in an HTML form with data from a Perl data structure, allowing you
to keep the HTML and Perl separate.

Here are two common use cases:

1. A user submits an HTML form without filling out a required field.  You want
to redisplay the form with all the previous data in it, to make it easy for the
user to see and correct the error. 

2. You have just retrieved a record from a database and need to display it in
an HTML form.

=head1 SYNOPSIS

Fill HTML form with data.

  $output = HTML::FillInForm->fill( \$html,   $q );
  $output = HTML::FillInForm->fill( \@html,   [$q1,$q2] );
  $output = HTML::FillInForm->fill( \*HTML,   \%data );
  $output = HTML::FillInForm->fill( 't.html', [\%data1,%data2] );

The HTML can be provided as a scalarref, arrayref, filehandle or file.  The data can come from one or more
hashrefs, or objects which support a param() method, like CGI.pm, L<Apache::Request|Apache::Request>, etc. 

=head1 fill

The basic syntax is seen above the Synopsis. There are a few additional options.

=head2 Options

=head3  target => 'form1'

Suppose you have multiple forms in a html file and only want to fill in one.

  $output = HTML::FillInForm->fill(\$html, $q, target => 'form1');

This will fill in only the form inside

  <FORM name="form1"> ... </FORM>

=head3 fill_password => 0

Passwords are filled in by default. To disable:

  fill_password => 0

=head3 ignore_fields => []

To disable the filling of some fields:

    ignore_fields => ['prev','next']

=head3 disable_fields => []

To disable fields from being edited:

    disable_fields => [ 'uid', 'gid' ]

=head2 File Upload fields

File upload fields cannot be supported directly. Workarounds include asking the
user to re-attach any file uploads or fancy server-side storage and
referencing. You are on your own.

=head2 Clearing Fields

Fields are cleared if you set their value to an empty string or empty arrayref but not undef:

  # this will leave the form element foo untouched
  HTML::FillInForm->fill(\$html, { foo => undef });

  # this will set clear the form element foo
  HTML::FillInForm->fill(\$html, { foo => "" });

It has been suggested to add a option to change the behavior so that undef
values will clear the form elements.  Patches welcome.

=head1 Old syntax

You probably need to read no further. The remaining docs concern the
1.x era syntax, which is still supported. 

=head2 new

Call C<new()> to create a new FillInForm object:

  $fif = HTML::FillInForm->new;
  $fif->fill(...);

In theory, there is a slight performance benefit to calling C<new()> before C<fill()> if you make multiple 
calls to C<fill()> before you destroy the object. Benchmark before optimizing. 

=head2 fill ( old syntax ) 

Instead of having your HTML and data types auto-detected, you can declare them explicitly in your
call to C<fill()>:

HTML source options:

    arrayref  => @html
    scalarref => $html
    file      => \*HTML 
    file      => 't.html'

Fill Data options:

    fobject   => $data_obj  # with param() method
    fdat      => \%data

Additional methods are also available:

    fill_file(\*HTML,...);
    fill_file('t.html',...);
    fill_arrayref(\@html,...);
    fill_scalarref(\$html,...);

=head1 CALLING FROM OTHER MODULES

=head2 Apache::PageKit

To use HTML::FillInForm in L<Apache::PageKit> is easy.   It is
automatically called for any page that includes a <form> tag.
It can be turned on or off by using the C<fill_in_form> configuration
option.

=head2 Apache::ASP v2.09 and above

HTML::FillInForm is now integrated with Apache::ASP.  To activate, use

  PerlSetVar FormFill 1
  $Response->{FormFill} = 1

=head2 HTML::Mason

Using HTML::FillInForm from HTML::Mason is covered in the FAQ on
the masonhq.com website at
L<http://www.masonhq.com/?FAQ:HTTPAndHTML#h-how_can_i_populate_form_values_automatically_>

=head1 VERSION

This documentation describes HTML::FillInForm module version 2.00

=head1 SECURITY

Note that you might want to think about caching issues if you have password
fields on your page.  There is a discussion of this issue at

http://www.perlmonks.org/index.pl?node_id=70482

In summary, some browsers will cache the output of CGI scripts, and you
can control this by setting the Expires header.  For example, use
C<-expires> in L<CGI.pm> or set C<browser_cache> to I<no> in 
Config.xml file of L<Apache::PageKit>.

=head1 TRANSLATION

Kato Atsushi has translated these docs into Japanese, available from

http://perldoc.jp

=head1 BUGS

Please submit any bug reports to tjmather@maxmind.com.

=head1 NOTES

Requires Perl 5.005 and L<HTML::Parser> version 3.26.

I wrote this module because I wanted to be able to insert CGI data
into HTML forms,
but without combining the HTML and Perl code.  CGI.pm and Embperl allow you so
insert CGI data into forms, but require that you mix HTML with Perl.

There is a nice review of the module available here:
L<http://www.perlmonks.org/index.pl?node_id=274534>

=head1 AUTHOR

(c) 2005 TJ Mather, tjmather@maxmind.com, L<http://www.maxmind.com/>

All rights reserved. This package is free software; you can
redistribute it and/or modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<HTML::Parser|HTML::Parser>, 
L<Data::FormValidator|Data::FormValidato>, 
L<HTML::Template|HTML::Template>, 
L<Apache::PageKit|Apache::PageKit>

=head1 CREDITS

Fixes, Bug Reports, Docs have been generously provided by:

  Tatsuhiko Miyagawa            Joseph Yanni
  Boris Zentner                 Philip Mak
  Dave Rolsky                   Jost Krieger
  Patrick Michael Kane          Gabriel Burka
  Ade Olonoh                    Bill Moseley
  Tom Lancaster                 James Tolley
  Martin H Sluka                Dan Kubb
  Mark Stosberg                 Alexander Hartmaier
  Jonathan Swartz               Paul Miller
  Trevor Schellhorn             Anthony Ettinger
  Jim Miner                     Simon P. Ditner
  Paul Lindner                  Michael Peters
  Maurice Aubrey                Trevor Schellhorn
  Andrew Creer                

Thanks!
