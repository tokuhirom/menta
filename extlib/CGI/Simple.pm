package CGI::Simple;

require 5.004;

# this module is both strict (and warnings) compliant, but they are only used
# in testing as they add an unnecessary compile time overhead in production.
use strict;
use warnings;
use Carp;

use vars qw(
 $VERSION $USE_CGI_PM_DEFAULTS $DISABLE_UPLOADS $POST_MAX
 $NO_UNDEF_PARAMS $USE_PARAM_SEMICOLONS $PARAM_UTF8 $HEADERS_ONCE
 $NPH $DEBUG $NO_NULL $FATAL *in
);

$VERSION = "1.106";

# you can hard code the global variable settings here if you want.
# warning - do not delete the unless defined $VAR part unless you
# want to permanently remove the ability to change the variable.
sub _initialize_globals {

  # set this to 1 to use CGI.pm default global settings
  $USE_CGI_PM_DEFAULTS = 0
   unless defined $USE_CGI_PM_DEFAULTS;

  # see if user wants old CGI.pm defaults
  if ( $USE_CGI_PM_DEFAULTS ) {
    _use_cgi_pm_global_settings();
    return;
  }

  # no file uploads by default, set to 0 to enable uploads
  $DISABLE_UPLOADS = 1
   unless defined $DISABLE_UPLOADS;

  # use a post max of 100K, set to -1 for no limits
  $POST_MAX = 102_400
   unless defined $POST_MAX;

  # set to 1 to not include undefined params parsed from query string
  $NO_UNDEF_PARAMS = 0
   unless defined $NO_UNDEF_PARAMS;

  # separate the name=value pairs with ; rather than &
  $USE_PARAM_SEMICOLONS = 0
   unless defined $USE_PARAM_SEMICOLONS;

  # return everything as utf-8
  $PARAM_UTF8 ||= 0;
  $PARAM_UTF8 and require Encode;

  # only print headers once
  $HEADERS_ONCE = 0
   unless defined $HEADERS_ONCE;

  # Set this to 1 to enable NPH scripts
  $NPH = 0
   unless defined $NPH;

  # 0 => no debug, 1 => from @ARGV,  2 => from STDIN
  $DEBUG = 0
   unless defined $DEBUG;

  # filter out null bytes in param - value pairs
  $NO_NULL = 1
   unless defined $NO_NULL;

# set behavior when cgi_err() called -1 => silent, 0 => carp, 1 => croak
  $FATAL = -1
   unless defined $FATAL;
}

# I happen to disagree with many of the default global settings in CGI.pm
# This sub is called if you set $CGI::Simple::USE_CGI_PM_GLOBALS = 1; or
# invoke the '-default' pragma via a use CGI::Simple qw(-default);
sub _use_cgi_pm_global_settings {
  $USE_CGI_PM_DEFAULTS  = 1;
  $DISABLE_UPLOADS      = 0 unless defined $DISABLE_UPLOADS;
  $POST_MAX             = -1 unless defined $POST_MAX;
  $NO_UNDEF_PARAMS      = 0 unless defined $NO_UNDEF_PARAMS;
  $USE_PARAM_SEMICOLONS = 1 unless defined $USE_PARAM_SEMICOLONS;
  $HEADERS_ONCE         = 0 unless defined $HEADERS_ONCE;
  $NPH                  = 0 unless defined $NPH;
  $DEBUG                = 1 unless defined $DEBUG;
  $NO_NULL              = 0 unless defined $NO_NULL;
  $FATAL                = -1 unless defined $FATAL;
  $PARAM_UTF8           = 0 unless defined $PARAM_UTF8;
}

# this is called by new, we will never directly reference the globals again
sub _store_globals {
  my $self = shift;

  $self->{'.globals'}->{'DISABLE_UPLOADS'}      = $DISABLE_UPLOADS;
  $self->{'.globals'}->{'POST_MAX'}             = $POST_MAX;
  $self->{'.globals'}->{'NO_UNDEF_PARAMS'}      = $NO_UNDEF_PARAMS;
  $self->{'.globals'}->{'USE_PARAM_SEMICOLONS'} = $USE_PARAM_SEMICOLONS;
  $self->{'.globals'}->{'HEADERS_ONCE'}         = $HEADERS_ONCE;
  $self->{'.globals'}->{'NPH'}                  = $NPH;
  $self->{'.globals'}->{'DEBUG'}                = $DEBUG;
  $self->{'.globals'}->{'NO_NULL'}              = $NO_NULL;
  $self->{'.globals'}->{'FATAL'}                = $FATAL;
  $self->{'.globals'}->{'USE_CGI_PM_DEFAULTS'}  = $USE_CGI_PM_DEFAULTS;
  $self->{'.globals'}->{'PARAM_UTF8'}           = $PARAM_UTF8;
}

# use the automatic calling of the import sub to set our pragmas. CGI.pm compat
sub import {
  my ( $self, @args ) = @_;

# arguments supplied in the 'use CGI::Simple [ARGS];' will now be in @args
  foreach ( @args ) {
    $USE_CGI_PM_DEFAULTS = 1, next if m/^-default/i;
    $DISABLE_UPLOADS     = 1, next if m/^-no.?upload/i;
    $DISABLE_UPLOADS     = 0, next if m/^-upload/i;
    $HEADERS_ONCE        = 1, next if m/^-unique.?header/i;
    $NPH                 = 1, next if m/^-nph/i;
    $DEBUG               = 0, next if m/^-no.?debug/i;
    $DEBUG = defined $1 ? $1 : 2, next if m/^-debug(\d)?/i;
    $USE_PARAM_SEMICOLONS = 1, next if m/^-newstyle.?url/i;
    $USE_PARAM_SEMICOLONS = 0, next if m/^-oldstyle.?url/i;
    $NO_UNDEF_PARAMS      = 1, next if m/^-no.?undef.?param/i;
    $FATAL                = 0, next if m/^-carp/i;
    $FATAL                = 1, next if m/^-croak/i;
    croak "Pragma '$_' is not defined in CGI::Simple\n";
  }
}

# used in CGI.pm .t files
sub _reset_globals {
  _use_cgi_pm_global_settings();
}

binmode STDIN;
binmode STDOUT;

# use correct encoding conversion to handle non ASCII char sets.
# we import and install the complex routines only if we have to.
BEGIN {

  sub url_decode {
    my ( $self, $decode ) = @_;
    return () unless defined $decode;
    $decode =~ tr/+/ /;
    $decode =~ s/%([a-fA-F0-9]{2})/ pack "C", hex $1 /eg;
    return $decode;
  }

  sub url_encode {
    my ( $self, $encode ) = @_;
    return () unless defined $encode;
    $encode
     =~ s/([^A-Za-z0-9\-_.!~*'() ])/ uc sprintf "%%%02x",ord $1 /eg;
    $encode =~ tr/ /+/;
    return $encode;
  }

  if ( "\t" ne "\011" ) {
    eval { require CGI::Simple::Util };
    if ( $@ ) {
      croak
       "Your server is using not using ASCII, you must install CGI::Simple::Util, error: $@";
    }

    # hack the symbol table and replace simple encode/decode subs
    *CGI::Simple::url_encode
     = sub { CGI::Simple::Util::escape( $_[1] ) };
    *CGI::Simple::url_decode
     = sub { CGI::Simple::Util::unescape( $_[1] ) };
  }
}

################ The Guts ################

sub new {
  my ( $class, $init ) = @_;
  $class = ref( $class ) || $class;
  my $self = {};
  bless $self, $class;
  if ( $self->_mod_perl ) {
    if ( $init ) {
      $self->{'.mod_perl_request'} = $init;
      undef $init;    # otherwise _initialize takes the wrong path
    }
    $self->_initialize_mod_perl();
  }
  $self->_initialize_globals;
  $self->_store_globals;
  $self->_initialize( $init );
  return $self;
}

sub _mod_perl {
  return (
    exists $ENV{MOD_PERL}
     or ( $ENV{GATEWAY_INTERFACE}
      and $ENV{GATEWAY_INTERFACE} =~ m{^CGI-Perl/} )
  );
}

# Return the global request object under mod_perl. If you use mod_perl 2
# and you don't set PerlOptions +GlobalRequest then the request must be
# passed in to the new() method.
sub _mod_perl_request {
  my $self = shift;

  my $mp = $self->{'.mod_perl'};

  return unless $mp;

  my $req = $self->{'.mod_perl_request'};
  return $req if $req;

  $self->{'.mod_perl_request'} = do {
    if ( $mp == 2 ) {
      Apache2::RequestUtil->request;
    }
    else {
      Apache->request;
    }
  };
}

sub _initialize_mod_perl {
  my ( $self ) = @_;

  eval "require mod_perl";

  if ( defined $mod_perl::VERSION ) {

    if ( $mod_perl::VERSION >= 2.00 ) {
      $self->{'.mod_perl'} = 2;

      require Apache2::RequestRec;
      require Apache2::RequestIO;
      require Apache2::RequestUtil;
      require Apache2::Response;
      require APR::Pool;

      my $r = $self->_mod_perl_request();

      if ( defined $r ) {
        $r->subprocess_env unless exists $ENV{REQUEST_METHOD};
        $r->pool->cleanup_register(
          \&CGI::Simple::_initialize_globals );
      }
    }
    else {
      $self->{'.mod_perl'} = 1;

      require Apache;

      my $r = $self->_mod_perl_request();

      if ( defined $r ) {
        $r->register_cleanup( \&CGI::Simple::_initialize_globals );
      }
    }
  }
}

sub _initialize {
  my ( $self, $init ) = @_;

  if ( !defined $init ) {

    # initialize from QUERY_STRING, STDIN or @ARGV
    $self->_read_parse();
  }
  elsif ( ( ref $init ) =~ m/HASH/i ) {

    # initialize from param hash
    for my $param ( keys %{$init} ) {
      $self->_add_param( $param, $init->{$param} );
    }
  }

  # chromatic's blessed GLOB patch
  # elsif ( (ref $init) =~ m/GLOB/i ) { # initialize from a file
  elsif ( UNIVERSAL::isa( $init, 'GLOB' ) ) {   # initialize from a file
    $self->_init_from_file( $init );
  }
  elsif ( ( ref $init ) eq 'CGI::Simple' ) {

    # initialize from a CGI::Simple object
    require Data::Dumper;

    # avoid problems with strict when Data::Dumper returns $VAR1
    my $VAR1;
    my $clone = eval( Data::Dumper::Dumper( $init ) );
    if ( $@ ) {
      $self->cgi_error( "Can't clone CGI::Simple object: $@" );
    }
    else {
      $_[0] = $clone;
    }
  }
  else {
    $self->_parse_params( $init );    # initialize from a query string
  }
}

sub _internal_read($\$;$) {
  my ( $self, $buffer, $len ) = @_;
  $len = 4096 if !defined $len;
  if ( $self->{'.mod_perl'} ) {
    my $r = $self->_mod_perl_request();
    $r->read( $$buffer, $len );
  }
  else {
    read( STDIN, $$buffer, $len );
  }
}

sub _read_parse {
  my $self   = shift;
  my $data   = '';
  my $type   = $ENV{'CONTENT_TYPE'} || 'No CONTENT_TYPE received';
  my $length = $ENV{'CONTENT_LENGTH'} || 0;
  my $method = $ENV{'REQUEST_METHOD'} || 'No REQUEST_METHOD received';

  # first check POST_MAX Steve Purkis pointed out the previous bug
  if (  ( $method eq 'POST' or $method eq "PUT" )
    and $self->{'.globals'}->{'POST_MAX'} != -1
    and $length > $self->{'.globals'}->{'POST_MAX'} ) {
    $self->cgi_error(
      "413 Request entity too large: $length bytes on STDIN exceeds \$POST_MAX!"
    );

    # silently discard data ??? better to just close the socket ???
    while ( $length > 0 ) {
      last unless _internal_read( $self, my $buffer );
      $length -= length( $buffer );
    }

    return;
  }

  if ( $length and $type =~ m|^multipart/form-data|i ) {
    my $got_length = $self->_parse_multipart;
    if ( $length != $got_length ) {
      $self->cgi_error(
        "500 Bad read on multipart/form-data! wanted $length, got $got_length"
      );
    }

    return;
  }
  elsif ( $method eq 'POST' or $method eq 'PUT' ) {
    if ( $length ) {

      # we may not get all the data we want with a single read on large
      # POSTs as it may not be here yet! Credit Jason Luther for patch
      # CGI.pm < 2.99 suffers from same bug
      _internal_read( $self, $data, $length );
      while ( length( $data ) < $length ) {
        last unless _internal_read( $self, my $buffer );
        $data .= $buffer;
      }

      unless ( $length == length $data ) {
        $self->cgi_error( "500 Bad read on POST! wanted $length, got "
           . length( $data ) );
        return;
      }

      if ( $type !~ m|^application/x-www-form-urlencoded| ) {
        $self->_add_param( $method . "DATA", $data );
      }
      else {
        $self->_parse_params( $data );
      }
    }
  }
  elsif ( $method eq 'GET' or $method eq 'HEAD' ) {
    $data
     = $self->{'.mod_perl'}
     ? $self->_mod_perl_request()->args()
     : $ENV{'QUERY_STRING'}
     || $ENV{'REDIRECT_QUERY_STRING'}
     || '';
    $self->_parse_params( $data );
  }
  else {
    unless ( $self->{'.globals'}->{'DEBUG'}
      and $data = $self->read_from_cmdline() ) {
      $self->cgi_error( "400 Unknown method $method" );
      return;
    }

    unless ( $data ) {

# I liked this reporting but CGI.pm does not behave like this so
# out it goes......
# $self->cgi_error("400 No data received via method: $method, type: $type");
      return;
    }

    $self->_parse_params( $data );
  }
}

sub _parse_params {
  my ( $self, $data ) = @_;
  return () unless defined $data;
  unless ( $data =~ /[&=;]/ ) {
    $self->{'keywords'} = [ $self->_parse_keywordlist( $data ) ];
    return;
  }
  my @pairs = split /[&;]/, $data;
  for my $pair ( @pairs ) {
    my ( $param, $value ) = split /=/, $pair, 2;
    next unless defined $param;
    $value = '' unless defined $value;
    $self->_add_param( $self->url_decode( $param ),
      $self->url_decode( $value ) );
  }
}

sub _add_param {
  my ( $self, $param, $value, $overwrite ) = @_;
  return () unless defined $param and defined $value;
  $param =~ tr/\000//d if $self->{'.globals'}->{'NO_NULL'};
  @{ $self->{$param} } = () if $overwrite;
  @{ $self->{$param} } = () unless exists $self->{$param};
  my @values = ref $value ? @{$value} : ( $value );
  for my $value ( @values ) {
    next
     if $value eq ''
       and $self->{'.globals'}->{'NO_UNDEF_PARAMS'};
    $value =~ tr/\000//d if $self->{'.globals'}->{'NO_NULL'};
    $value = Encode::decode( utf8 => $value )
     if $self->{'.globals'}->{PARAM_UTF8};
    push @{ $self->{$param} }, $value;
    unless ( $self->{'.fieldnames'}->{$param} ) {
      push @{ $self->{'.parameters'} }, $param;
      $self->{'.fieldnames'}->{$param}++;
    }
  }
  return scalar @values;    # for compatibility with CGI.pm request.t
}

sub _parse_keywordlist {
  my ( $self, $data ) = @_;
  return () unless defined $data;
  $data = $self->url_decode( $data );
  $data =~ tr/\000//d if $self->{'.globals'}->{'NO_NULL'};
  my @keywords = split /\s+/, $data;
  return @keywords;
}

sub _parse_multipart {
  my $self = shift;

  # TODO: See 14838. We /could/ have a heuristic here for the case
  # where no boundary is supplied.

  my ( $boundary )
   = $ENV{'CONTENT_TYPE'} =~ /boundary=\"?([^\";,]+)\"?/;
  unless ( $boundary ) {
    $self->cgi_error(
      '400 No boundary supplied for multipart/form-data' );
    return 0;
  }

# BUG: IE 3.01 on the Macintosh uses just the boundary, forgetting the --
  $boundary = '--' . $boundary
   unless exists $ENV{'HTTP_USER_AGENT'}
     && $ENV{'HTTP_USER_AGENT'} =~ m/MSIE\s+3\.0[12];\s*Mac/i;

  $boundary = quotemeta $boundary;
  my $got_data = 0;
  my $data     = '';
  my $length   = $ENV{'CONTENT_LENGTH'} || 0;
  my $CRLF     = $self->crlf;

  READ:

  while ( $got_data < $length ) {
    last READ unless _internal_read( $self, my $buffer );
    $data .= $buffer;
    $got_data += length $buffer;

    BOUNDARY:

    while ( $data =~ m/^$boundary$CRLF/ ) {
      ## TAB and high ascii chars are definitivelly allowed in headers.
      ## Not accepting them in the following regex prevents the upload of
      ## files with filenames like "España.txt".
      # next READ unless $data =~ m/^([\040-\176$CRLF]+?$CRLF$CRLF)/o;
      next READ
       unless $data =~ m/^([\x20-\x7E\x80-\xFF\x09$CRLF]+?$CRLF$CRLF)/o;
      my $header = $1;
      ( my $unfold = $1 ) =~ s/$CRLF\s+/ /og;
      my ( $param ) = $unfold =~ m/form-data;\s+name="?([^\";]*)"?/;
      my ( $filename )
       = $unfold =~ m/name="?\Q$param\E"?;\s+filename="?([^\"]*)"?/;
      if ( defined $filename ) {
        my ( $mime ) = $unfold =~ m/Content-Type:\s+([-\w\/]+)/io;
        $data =~ s/^\Q$header\E//;
        ( $got_data, $data, my $fh, my $size )
         = $self->_save_tmpfile( $boundary, $filename, $got_data,
          $data );
        $self->_add_param( $param, $filename );
        $self->{'.upload_fields'}->{$param} = $filename;
        $self->{'.filehandles'}->{$filename} = $fh if $fh;
        $self->{'.tmpfiles'}->{$filename}
         = { 'size' => $size, 'mime' => $mime }
         if $size;
        next BOUNDARY;
      }
      next READ
       unless $data =~ s/^\Q$header\E(.*?)$CRLF(?=$boundary)//s;
      $self->_add_param( $param, $1 );
    }
    unless ( $data =~ m/^$boundary/ ) {
      ## In a perfect world, $data should always begin with $boundary.
      ## But sometimes, IE5 prepends garbage boundaries into POST(ed) data.
      ## Then, $data does not start with $boundary and the previous block
      ## never gets executed. The following fix attempts to remove those
      ## extra boundaries from readed $data and restart boundary parsing.
      ## Note about performance: with well formed data, previous check is
      ## executed (generally) only once, when $data value is "$boundary--"
      ## at end of parsing.
      goto BOUNDARY if ( $data =~ s/.*?$CRLF(?=$boundary$CRLF)//s );
    }
  }
  return $got_data;
}

sub _save_tmpfile {
  my ( $self, $boundary, $filename, $got_data, $data ) = @_;
  my $fh;
  my $CRLF      = $self->crlf;
  my $length    = $ENV{'CONTENT_LENGTH'} || 0;
  my $file_size = 0;
  if ( $self->{'.globals'}->{'DISABLE_UPLOADS'} ) {
    $self->cgi_error( "405 Not Allowed - File uploads are disabled" );
  }
  elsif ( $filename ) {
    eval { require IO::File };
    $self->cgi_error( "500 IO::File is not available $@" ) if $@;
    $fh = new_tmpfile IO::File;
    $self->cgi_error( "500 IO::File can't create new temp_file" )
     unless $fh;
  }

# read in data until closing boundary found. buffer to catch split boundary
# we do this regardless of whether we save the file or not to read the file
# data from STDIN. if either uploads are disabled or no file has been sent
# $fh will be undef so only do file stuff if $fh is true using $fh && syntax
  $fh && binmode $fh;
  while ( $got_data < $length ) {

    my $buffer = $data;
    last unless _internal_read( $self, $data );

    # fixed hanging bug if browser terminates upload part way through
    # thanks to Brandon Black
    unless ( $data ) {
      $self->cgi_error(
        '400 Malformed multipart, no terminating boundary' );
      undef $fh;
      return $got_data;
    }

    $got_data += length $data;
    if ( "$buffer$data" =~ m/$boundary/ ) {
      $data = $buffer . $data;
      last;
    }

    # we do not have partial boundary so print to file if valid $fh
    $fh && print $fh $buffer;
    $file_size += length $buffer;
  }
  $data =~ s/^(.*?)$CRLF(?=$boundary)//s;
  $fh && print $fh $1;    # print remainder of file if valid $fh
  $file_size += length $1;
  return $got_data, $data, $fh, $file_size;
}

# Define the CRLF sequence.  You can't use a simple "\r\n" because of system
# specific 'features'. On EBCDIC systems "\t" ne "\011" as the don't use ASCII
sub crlf {
  my ( $self, $CRLF ) = @_;
  $self->{'.crlf'} = $CRLF if $CRLF;    # allow value to be set manually
  unless ( $self->{'.crlf'} ) {
    my $OS = $^O
     || do { require Config; $Config::Config{'osname'} };
    $self->{'.crlf'}
     = ( $OS =~ m/VMS/i ) ? "\n"
     : ( "\t" ne "\011" ) ? "\r\n"
     :                      "\015\012";
  }
  return $self->{'.crlf'};
}

################ The Core Methods ################

sub param {
  my ( $self, $param, @p ) = @_;
  unless ( defined $param ) {    # return list of all params
    my @params
     = $self->{'.parameters'} ? @{ $self->{'.parameters'} } : ();
    return @params;
  }
  unless ( @p ) {                # return values for $param
    return () unless exists $self->{$param};
    return wantarray ? @{ $self->{$param} } : $self->{$param}->[0];
  }
  if ( $param =~ m/^-name$/i and @p == 1 ) {
    return () unless exists $self->{ $p[0] };
    return wantarray ? @{ $self->{ $p[0] } } : $self->{ $p[0] }->[0];
  }

  # set values using -name=>'foo',-value=>'bar' syntax.
  # also allows for $q->param( 'foo', 'some', 'new', 'values' ) syntax
  ( $param, undef, @p ) = @p
   if $param =~ m/^-name$/i;     # undef represents -value token
  $self->_add_param( $param, ( ref $p[0] eq 'ARRAY' ? $p[0] : [@p] ),
    'overwrite' );
  return wantarray ? @{ $self->{$param} } : $self->{$param}->[0];
}

#1;

###############   The following methods only loaded on demand   ###############
###############  Move commonly used methods above the __DATA__  ###############
############### token if you are into recreational optimization ###############
###############  You can not use Selfloader and the __DATA__    ###############
###############   token under mod_perl, so comment token out    ###############

#__DATA__

# a new method that provides access to a new internal routine. Useage:
# $q->add_param( $param, $value, $overwrite )
# $param must be a plain scalar
# $value may be either a scalar or an array ref
# if $overwrite is a true value $param will be overwritten with new values.
sub add_param {
  _add_param( @_ );
}

sub param_fetch {
  my ( $self, $param, @p ) = @_;
  $param
   = ( defined $param and $param =~ m/^-name$/i ) ? $p[0] : $param;
  return undef unless defined $param;
  $self->_add_param( $param, [] ) unless exists $self->{$param};
  return $self->{$param};
}

# Return a parameter in the QUERY_STRING, regardless of whether a POST or GET
sub url_param {
  my ( $self, $param ) = @_;
  return () unless $ENV{'QUERY_STRING'};
  $self->{'.url_param'} = {};
  bless $self->{'.url_param'}, 'CGI::Simple';
  $self->{'.url_param'}->_parse_params( $ENV{'QUERY_STRING'} );
  return $self->{'.url_param'}->param( $param );
}

sub keywords {
  my ( $self, @values ) = @_;
  $self->{'keywords'}
   = ref $values[0] eq 'ARRAY' ? $values[0] : [@values]
   if @values;
  my @result
   = defined( $self->{'keywords'} ) ? @{ $self->{'keywords'} } : ();
  return @result;
}

sub Vars {
  my $self = shift;
  $self->{'.sep'} = shift || $self->{'.sep'} || "\0";
  my ( %hash, %tied );
  for my $param ( $self->param ) {
    $hash{$param} = join $self->{'.sep'}, $self->param( $param );
  }
  tie %tied, "CGI::Simple", $self;
  return wantarray ? %hash : \%tied;
}

sub TIEHASH { $_[1] ? $_[1] : new $_[0] }

sub STORE {
  my ( $q, $p, $v ) = @_;
  $q->param( $p, split $q->{'.sep'}, $v );
}

sub FETCH {
  my ( $q, $p ) = @_;
  ref $q->{$p} eq "ARRAY" ? join $q->{'.sep'}, @{ $q->{$p} } : $q->{$p};
}
sub FIRSTKEY { my $a = scalar keys %{ $_[0] }; each %{ $_[0] } }
sub NEXTKEY { each %{ $_[0] } }
sub EXISTS  { exists $_[0]->{ $_[1] } }
sub DELETE  { $_[0]->delete( $_[1] ) }
sub CLEAR   { %{ $_[0] } = () }

sub append {
  my ( $self, $param, @p ) = @_;
  return () unless defined $param;

  # set values using $q->append(-name=>'foo',-value=>'bar') syntax
  # also allows for $q->append( 'foo', 'some', 'new', 'values' ) syntax
  ( $param, undef, @p ) = @p
   if $param =~ m/^-name$/i;    # undef represents -value token
  $self->_add_param( $param,
    ( ( defined $p[0] and ref $p[0] ) ? $p[0] : [@p] ) );
  return $self->param( $param );
}

sub delete {
  my ( $self, $param ) = @_;
  return () unless defined $param;
  $param
   = $param =~ m/^-name$/i
   ? shift
   : $param;                    # allow delete(-name=>'foo') syntax
  return undef unless defined $self->{$param};
  delete $self->{$param};
  delete $self->{'.fieldnames'}->{$param};
  $self->{'.parameters'}
   = [ grep { $_ ne $param } @{ $self->{'.parameters'} } ];
}

sub Delete { CGI::Simple::delete( @_ ) }    # for method style interface

sub delete_all {
  my $self = shift;
  undef %{$self};
  $self->_store_globals;
}

sub Delete_all { $_[0]->delete_all }        # as used by CGI.pm

sub upload {
  my ( $self, $filename, $writefile ) = @_;
  unless ( $filename ) {
    $self->cgi_error( "No filename submitted for upload to $writefile" )
     if $writefile;
    return $self->{'.filehandles'}
     ? keys %{ $self->{'.filehandles'} }
     : ();
  }
  unless ( $ENV{'CONTENT_TYPE'} =~ m|^multipart/form-data|i ) {
    $self->cgi_error(
      'Oops! File uploads only work if you specify ENCTYPE="multipart/form-data" in your <FORM> tag'
    );
    return undef;
  }
  my $fh = $self->{'.filehandles'}->{$filename};

  # allow use of upload fieldname to get filehandle
  # this has limitation that in the event of duplicate
  # upload field names there can only be one filehandle
  # which will point to the last upload file
  # access by filename does not suffer from this issue.
  $fh
   = $self->{'.filehandles'}->{ $self->{'.upload_fields'}->{$filename} }
   if !$fh and defined $self->{'.upload_fields'}->{$filename};

  if ( $fh ) {
    seek $fh, 0, 0;    # get ready for reading
    return $fh unless $writefile;
    my $buffer;
    unless ( open OUT, ">$writefile" ) {
      $self->cgi_error( "500 Can't write to $writefile: $!\n" );
      return undef;
    }
    binmode OUT;
    binmode $fh;
    print OUT $buffer while read( $fh, $buffer, 4096 );
    close OUT;
    $self->{'.filehandles'}->{$filename} = undef;
    undef $fh;
    return 1;
  }
  else {
    $self->cgi_error(
      "No filehandle for '$filename'. Are uploads enabled (\$DISABLE_UPLOADS = 0)? Is \$POST_MAX big enough?"
    );
    return undef;
  }
}

sub upload_fieldnames {
  my ( $self ) = @_;
  return wantarray
   ? ( keys %{ $self->{'.upload_fields'} } )
   : [ keys %{ $self->{'.upload_fields'} } ];
}

# return the file size of an uploaded file
sub upload_info {
  my ( $self, $filename, $info ) = @_;
  unless ( $ENV{'CONTENT_TYPE'} =~ m|^multipart/form-data|i ) {
    $self->cgi_error(
      'Oops! File uploads only work if you specify ENCTYPE="multipart/form-data" in your <FORM> tag'
    );
    return undef;
  }
  return keys %{ $self->{'.tmpfiles'} } unless $filename;
  return $self->{'.tmpfiles'}->{$filename}->{'mime'}
   if $info =~ /mime/i;
  return $self->{'.tmpfiles'}->{$filename}->{'size'};
}

sub uploadInfo { &upload_info }    # alias for CGI.pm compatibility

# return all params/values in object as a query string suitable for 'GET'
sub query_string {
  my $self = shift;
  my @pairs;
  for my $param ( $self->param ) {
    for my $value ( $self->param( $param ) ) {
      next unless defined $value;
      push @pairs,
       $self->url_encode( $param ) . '=' . $self->url_encode( $value );
    }
  }
  return join $self->{'.globals'}->{'USE_PARAM_SEMICOLONS'} ? ';' : '&',
   @pairs;
}

# new method that will add QUERY_STRING data to our CGI::Simple object
# if the REQUEST_METHOD was 'POST'
sub parse_query_string {
  my $self = shift;
  $self->_parse_params( $ENV{'QUERY_STRING'} )
   if defined $ENV{'QUERY_STRING'}
     and $ENV{'REQUEST_METHOD'} eq 'POST';
}

################   Save and Restore params from file    ###############

sub _init_from_file {
  my ( $self, $fh ) = @_;
  local $/ = "\n";
  while ( my $pair = <$fh> ) {
    chomp $pair;
    return if $pair eq '=';
    $self->_parse_params( $pair );
  }
}

sub save {
  my ( $self, $fh ) = @_;
  local ( $,, $\ ) = ( '', '' );
  unless ( $fh and fileno $fh ) {
    $self->cgi_error( 'Invalid filehandle' );
    return undef;
  }
  for my $param ( $self->param ) {
    for my $value ( $self->param( $param ) ) {
      ;
      print $fh $self->url_encode( $param ), '=',
       $self->url_encode( $value ), "\n";
    }
  }
  print $fh "=\n";
}

sub save_parameters { save( @_ ) }    # CGI.pm alias for save

################ Miscellaneous Methods ################

sub parse_keywordlist {
  _parse_keywordlist( @_ );
}                                     # CGI.pm compatibility

sub escapeHTML {
  my ( $self, $escape, $newlinestoo ) = @_;
  require CGI::Simple::Util;
  $escape = CGI::Simple::Util::escapeHTML( $escape );
  $escape =~ s/([\012\015])/'&#'.(ord $1).';'/eg if $newlinestoo;
  return $escape;
}

sub unescapeHTML {
  require CGI::Simple::Util;
  return CGI::Simple::Util::unescapeHTML( $_[1] );
}

sub put {
  my $self = shift;
  $self->print( @_ );
}    # send output to browser

sub print {
  shift;
  CORE::print( @_ );
}    # print to standard output (for overriding in mod_perl)

################# Cookie Methods ################

sub cookie {
  my ( $self, @params ) = @_;
  require CGI::Simple::Cookie;
  require CGI::Simple::Util;
  my ( $name, $value, $path, $domain, $secure, $expires )
   = CGI::Simple::Util::rearrange(
    [
      'NAME', [ 'VALUE', 'VALUES' ],
      'PATH',   'DOMAIN',
      'SECURE', 'EXPIRES'
    ],
    @params
   );

  # retrieve the value of the cookie, if no value is supplied
  unless ( defined( $value ) ) {
    $self->{'.cookies'} = CGI::Simple::Cookie->fetch
     unless $self->{'.cookies'};
    return () unless $self->{'.cookies'};

   # if no name is supplied, then retrieve the names of all our cookies.
    return keys %{ $self->{'.cookies'} } unless $name;

    # return the value of the cookie
    return
     exists $self->{'.cookies'}->{$name}
     ? $self->{'.cookies'}->{$name}->value
     : ();
  }

  # If we get here, we're creating a new cookie
  return undef unless $name;    # this is an error
  @params = ();
  push @params, '-name'    => $name;
  push @params, '-value'   => $value;
  push @params, '-domain'  => $domain if $domain;
  push @params, '-path'    => $path if $path;
  push @params, '-expires' => $expires if $expires;
  push @params, '-secure'  => $secure if $secure;
  return CGI::Simple::Cookie->new( @params );
}

sub raw_cookie {
  my ( $self, $key ) = @_;
  if ( defined $key ) {
    unless ( $self->{'.raw_cookies'} ) {
      require CGI::Simple::Cookie;
      $self->{'.raw_cookies'} = CGI::Simple::Cookie->raw_fetch;
    }
    return $self->{'.raw_cookies'}->{$key} || ();
  }
  return $ENV{'HTTP_COOKIE'} || $ENV{'COOKIE'} || '';
}

################# Header Methods ################

sub header {
  my ( $self, @params ) = @_;
  require CGI::Simple::Util;
  my @header;
  return undef
   if $self->{'.header_printed'}++
     and $self->{'.globals'}->{'HEADERS_ONCE'};
  my (
    $type, $status,  $cookie,     $target, $expires,
    $nph,  $charset, $attachment, $p3p,    @other
   )
   = CGI::Simple::Util::rearrange(
    [
      [ 'TYPE',   'CONTENT_TYPE', 'CONTENT-TYPE' ], 'STATUS',
      [ 'COOKIE', 'COOKIES',      'SET-COOKIE' ],   'TARGET',
      'EXPIRES', 'NPH',
      'CHARSET', 'ATTACHMENT',
      'P3P'
    ],
    @params
   );
  $nph ||= $self->{'.globals'}->{'NPH'};
  $charset = $self->charset( $charset )
   ;    # get charset (and set new charset if supplied)
   # rearrange() was designed for the HTML portion, so we need to fix it up a little.

  for ( @other ) {

    # Don't use \s because of perl bug 21951
    next
     unless my ( $header, $value ) = /([^ \r\n\t=]+)=\"?(.+?)\"?$/;
    ( $_ = $header )
     =~ s/^(\w)(.*)/"\u$1\L$2" . ': '.$self->unescapeHTML($value)/e;
  }
  $type ||= 'text/html' unless defined $type;
  $type .= "; charset=$charset"
   if $type
     and $type =~ m!^text/!
     and $type !~ /\bcharset\b/;
  my $protocol = $ENV{SERVER_PROTOCOL} || 'HTTP/1.0';
  push @header, $protocol . ' ' . ( $status || '200 OK' ) if $nph;
  push @header, "Server: " . server_software() if $nph;
  push @header, "Status: $status"              if $status;
  push @header, "Window-Target: $target"       if $target;

  if ( $p3p ) {
    $p3p = join ' ', @$p3p if ref( $p3p ) eq 'ARRAY';
    push( @header, qq(P3P: policyref="/w3c/p3p.xml", CP="$p3p") );
  }

  # push all the cookies -- there may be several
  if ( $cookie ) {
    my @cookie = ref $cookie eq 'ARRAY' ? @{$cookie} : $cookie;
    for my $cookie ( @cookie ) {
      my $cs
       = ref $cookie eq 'CGI::Simple::Cookie'
       ? $cookie->as_string
       : $cookie;
      push @header, "Set-Cookie: $cs" if $cs;
    }
  }

# if the user indicates an expiration time, then we need both an Expires
# and a Date header (so that the browser is using OUR clock)
  $expires = 'now'
   if $self->no_cache;    # encourage no caching via expires now
  push @header,
   "Expires: " . CGI::Simple::Util::expires( $expires, 'http' )
   if $expires;
  push @header, "Date: " . CGI::Simple::Util::expires( 0, 'http' )
   if defined $expires || $cookie || $nph;
  push @header, "Pragma: no-cache" if $self->cache or $self->no_cache;
  push @header,
   "Content-Disposition: attachment; filename=\"$attachment\""
   if $attachment;
  push @header, @other;
  push @header, "Content-Type: $type" if $type;
  my $CRLF = $self->crlf;
  my $header = join $CRLF, @header;
  $header .= $CRLF . $CRLF;    # add the statutory two CRLFs

  if ( $self->{'.mod_perl'} and not $nph ) {
    my $r = $self->_mod_perl_request();
    $r->send_cgi_header( $header );
    return '';
  }
  return $header;
}

# Control whether header() will produce the no-cache Pragma directive.
sub cache {
  my ( $self, $value ) = @_;
  $self->{'.cache'} = $value if defined $value;
  return $self->{'.cache'};
}

# Control whether header() will produce expires now + the no-cache Pragma.
sub no_cache {
  my ( $self, $value ) = @_;
  $self->{'.no_cache'} = $value if defined $value;
  return $self->{'.no_cache'};
}

sub redirect {
  my ( $self, @params ) = @_;
  require CGI::Simple::Util;
  my ( $url, $target, $cookie, $nph, @other )
   = CGI::Simple::Util::rearrange(
    [
      [ 'LOCATION', 'URI',       'URL' ], 'TARGET',
      [ 'COOKIE',   'COOKIES' ], 'NPH'
    ],
    @params
   );
  $url ||= $self->self_url;
  my @o;
  for ( @other ) { tr/\"//d; push @o, split "=", $_, 2; }
  unshift @o,
   '-Status'   => '302 Moved',
   '-Location' => $url,
   '-nph'      => $nph;
  unshift @o, '-Target' => $target if $target;
  unshift @o, '-Cookie' => $cookie if $cookie;
  unshift @o, '-Type'   => '';
  my @unescaped;
  unshift( @unescaped, '-Cookie' => $cookie ) if $cookie;
  return $self->header( ( map { $self->unescapeHTML( $_ ) } @o ),
    @unescaped );
}

################# Server Push Methods #################
# Return a Content-Type: style header for server-push
# This has to be NPH, and it is advisable to set $| = 1
# Credit to Ed Jordan <ed@fidalgo.net> and
# Andrew Benham <adsb@bigfoot.com> for this section

sub multipart_init {
  my ( $self, @p ) = @_;
  use CGI::Simple::Util qw(rearrange);
  my ( $boundary, @other ) = rearrange( ['BOUNDARY'], @p );
  $boundary = $boundary || '------- =_aaaaaaaaaa0';
  my $CRLF = $self->crlf;    # get CRLF sequence
  my $warning
   = "WARNING: YOUR BROWSER DOESN'T SUPPORT THIS SERVER-PUSH TECHNOLOGY.";
  $self->{'.separator'}       = "$CRLF--$boundary$CRLF";
  $self->{'.final_separator'} = "$CRLF--$boundary--$CRLF$warning$CRLF";
  my $type = 'multipart/x-mixed-replace;boundary="' . $boundary . '"';
  return $self->header(
    -nph  => 1,
    -type => $type,
    map { split "=", $_, 2 } @other
   )
   . $warning
   . $self->multipart_end;
}

sub multipart_start {
  my ( $self, @p ) = @_;
  use CGI::Simple::Util qw(rearrange);
  my ( $type, @other ) = rearrange( ['TYPE'], @p );
  foreach ( @other ) {    # fix return from rearange
    next unless my ( $header, $value ) = /([^\s=]+)=\"?(.+?)\"?$/;
    $_ = ucfirst( lc $header ) . ': ' . unescapeHTML( 1, $value );
  }
  $type = $type || 'text/html';
  my @header = ( "Content-Type: $type" );
  push @header, @other;
  my $CRLF = $self->crlf;    # get CRLF sequence
  return ( join $CRLF, @header ) . $CRLF . $CRLF;
}

sub multipart_end { return $_[0]->{'.separator'} }

sub multipart_final { return $_[0]->{'.final_separator'} }

################# Debugging Methods ################

sub read_from_cmdline {
  my @words;
  if ( $_[0]->{'.globals'}->{'DEBUG'} == 1 and @ARGV ) {
    @words = @ARGV;
  }
  elsif ( $_[0]->{'.globals'}->{'DEBUG'} == 2 ) {
    require "shellwords.pl";
    print "(offline mode: enter name=value pairs on standard input)\n";
    chomp( my @lines = <STDIN> );
    @words = &shellwords( join " ", @lines );
  }
  else {
    return '';
  }
  @words = map { s/\\=/%3D/g; s/\\&/%26/g; $_ } @words;
  return "@words" =~ m/=/ ? join '&', @words : join '+', @words;
}

sub Dump {
  require Data::Dumper;    # short and sweet way of doing it
  ( my $dump = Data::Dumper::Dumper( @_ ) )
   =~ tr/\000/0/;          # remove null bytes cgi-lib.pl
  return '<pre>' . escapeHTML( 1, $dump ) . '</pre>';
}

sub as_string { Dump( @_ ) }    # CGI.pm alias for Dump()

sub cgi_error {
  my ( $self, $err ) = @_;
  if ( $err ) {
    $self->{'.cgi_error'} = $err;
       $self->{'.globals'}->{'FATAL'} == 1 ? croak $err
     : $self->{'.globals'}->{'FATAL'} == 0 ? carp $err
     :                                       return $err;
  }
  return $self->{'.cgi_error'};
}

################# cgi-lib.pl Compatibility Methods #################
# Lightly GOLFED but the original functionality remains. You can call
# them using either: # $q->MethodName or CGI::Simple::MethodName

sub _shift_if_ref { shift if ref $_[0] eq 'CGI::Simple' }

sub ReadParse {
  my $q = &_shift_if_ref || new CGI::Simple;
  my $pkg = caller();
  no strict 'refs';
  *in
   = @_
   ? $_[0]
   : *{"${pkg}::in"};    # set *in to passed glob or export *in
  %in = $q->Vars;
  $in{'CGI'} = $q;
  return scalar %in;
}

sub SplitParam {
  &_shift_if_ref;
  defined $_[0]
   && ( wantarray ? split "\0", $_[0] : ( split "\0", $_[0] )[0] );
}

sub MethGet { request_method() eq 'GET' }

sub MethPost { request_method() eq 'POST' }

sub MyBaseUrl {
  local $^W = 0;
  'http://'
   . server_name()
   . ( server_port() != 80 ? ':' . server_port() : '' )
   . script_name();
}

sub MyURL { MyBaseUrl() }

sub MyFullUrl {
  local $^W = 0;
  MyBaseUrl()
   . $ENV{'PATH_INFO'}
   . ( $ENV{'QUERY_STRING'} ? "?$ENV{'QUERY_STRING'}" : '' );
}

sub PrintHeader {
  ref $_[0] ? $_[0]->header() : "Content-Type: text/html\n\n";
}

sub HtmlTop {
  &_shift_if_ref;
  "<html>\n<head>\n<title>$_[0]</title>\n</head>\n<body>\n<h1>$_[0]</h1>\n";
}

sub HtmlBot { "</body>\n</html>\n" }

sub PrintVariables { &_shift_if_ref; &Dump }

sub PrintEnv { &Dump( \%ENV ) }

sub CgiDie { CgiError( @_ ); die @_ }

sub CgiError {
  &_shift_if_ref;
  @_
   = @_
   ? @_
   : ( "Error: script " . MyFullUrl() . " encountered fatal error\n" );
  print PrintHeader(), HtmlTop( shift ), ( map { "<p>$_</p>\n" } @_ ),
   HtmlBot();
}

################ Accessor Methods ################

sub version { $VERSION }

sub nph {
  $_[0]->{'.globals'}->{'NPH'} = $_[1] if defined $_[1];
  return $_[0]->{'.globals'}->{'NPH'};
}

sub all_parameters { $_[0]->param }

sub charset {
  require CGI::Simple::Util;
  $CGI::Simple::Util::UTIL->charset( $_[1] );
}

sub globals {
  my ( $self, $global, $value ) = @_;
  return keys %{ $self->{'.globals'} } unless $global;
  $self->{'.globals'}->{$global} = $value if defined $value;
  return $self->{'.globals'}->{$global};
}

sub auth_type         { $ENV{'AUTH_TYPE'} }
sub content_length    { $ENV{'CONTENT_LENGTH'} }
sub content_type      { $ENV{'CONTENT_TYPE'} }
sub document_root     { $ENV{'DOCUMENT_ROOT'} }
sub gateway_interface { $ENV{'GATEWAY_INTERFACE'} }
sub path_translated   { $ENV{'PATH_TRANSLATED'} }
sub referer           { $ENV{'HTTP_REFERER'} }
sub remote_addr       { $ENV{'REMOTE_ADDR'} || '127.0.0.1' }

sub remote_host {
  $ENV{'REMOTE_HOST'} || $ENV{'REMOTE_ADDR'} || 'localhost';
}

sub remote_ident   { $ENV{'REMOTE_IDENT'} }
sub remote_user    { $ENV{'REMOTE_USER'} }
sub request_method { $ENV{'REQUEST_METHOD'} }
sub script_name    { $ENV{'SCRIPT_NAME'} || $0 || '' }
sub server_name     { $ENV{'SERVER_NAME'}     || 'localhost' }
sub server_port     { $ENV{'SERVER_PORT'}     || 80 }
sub server_protocol { $ENV{'SERVER_PROTOCOL'} || 'HTTP/1.0' }
sub server_software { $ENV{'SERVER_SOFTWARE'} || 'cmdline' }

sub user_name {
  $ENV{'HTTP_FROM'} || $ENV{'REMOTE_IDENT'} || $ENV{'REMOTE_USER'};
}

sub user_agent {
  my ( $self, $match ) = @_;
  return $match
   ? $ENV{'HTTP_USER_AGENT'} =~ /\Q$match\E/i
   : $ENV{'HTTP_USER_AGENT'};
}

sub virtual_host {
  my $vh = $ENV{'HTTP_HOST'} || $ENV{'SERVER_NAME'};
  $vh =~ s/:\d+$//;    # get rid of port number
  return $vh;
}

sub path_info {
  my ( $self, $info ) = @_;
  if ( defined $info ) {
    $info = "/$info" if $info !~ m|^/|;
    $self->{'.path_info'} = $info;
  }
  elsif ( !defined( $self->{'.path_info'} ) ) {
    $self->{'.path_info'}
     = defined( $ENV{'PATH_INFO'} ) ? $ENV{'PATH_INFO'} : '';

    # hack to fix broken path info in IIS source CGI.pm
    $self->{'.path_info'} =~ s/^\Q$ENV{'SCRIPT_NAME'}\E//
     if defined( $ENV{'SERVER_SOFTWARE'} )
       && $ENV{'SERVER_SOFTWARE'} =~ /IIS/;
  }
  return $self->{'.path_info'};
}

sub accept {
  my ( $self, $search ) = @_;
  my %prefs;
  for my $accept ( split ',', $ENV{'HTTP_ACCEPT'} ) {
    ( my $pref ) = $accept =~ m|q=([\d\.]+)|;
    ( my $type ) = $accept =~ m|(\S+/[^;]+)|;
    next unless $type;
    $prefs{$type} = $pref || 1;
  }
  return keys %prefs unless $search;
  return $prefs{$search} if $prefs{$search};

  # Didn't get it, so try pattern matching.
  for my $pref ( keys %prefs ) {
    next unless $pref =~ m/\*/;    # not a pattern match
    ( my $pat = $pref ) =~ s/([^\w*])/\\$1/g;   # escape meta characters
    $pat =~ s/\*/.*/g;                          # turn it into a pattern
    return $prefs{$pref} if $search =~ /$pat/;
  }
}

sub Accept { my $self = shift; $self->accept( @_ ) }

sub http {
  my ( $self, $parameter ) = @_;
  if ( defined $parameter ) {
    ( $parameter = uc $parameter ) =~ tr/-/_/;
    return $ENV{$parameter} if $parameter =~ m/^HTTP/;
    return $ENV{"HTTP_$parameter"} if $parameter;
  }
  return grep { /^HTTP/ } keys %ENV;
}

sub https {
  my ( $self, $parameter ) = @_;
  return $ENV{'HTTPS'} unless $parameter;
  ( $parameter = uc $parameter ) =~ tr/-/_/;
  return $ENV{$parameter} if $parameter =~ /^HTTPS/;
  return $ENV{"HTTPS_$parameter"};
}

sub protocol {
  local ( $^W ) = 0;
  my $self = shift;
  return 'https' if uc $ENV{'HTTPS'} eq 'ON';
  return 'https' if $self->server_port == 443;
  my ( $protocol, $version ) = split '/', $self->server_protocol;
  return lc $protocol;
}

sub url {
  my ( $self, @p ) = @_;
  use CGI::Simple::Util 'rearrange';
  my ( $relative, $absolute, $full, $path_info, $query, $base )
   = rearrange(
    [
      'RELATIVE', 'ABSOLUTE', 'FULL',
      [ 'PATH',  'PATH_INFO' ],
      [ 'QUERY', 'QUERY_STRING' ], 'BASE'
    ],
    @p
   );
  my $url;
  $full++ if $base || !( $relative || $absolute );
  my $path        = $self->path_info;
  my $script_name = $self->script_name;
  if ( $full ) {
    my $protocol = $self->protocol();
    $url = "$protocol://";
    my $vh = $self->http( 'host' );
    if ( $vh ) {
      $url .= $vh;
    }
    else {
      $url .= server_name();
      my $port = $self->server_port;
      $url .= ":" . $port
       unless ( lc( $protocol ) eq 'http' && $port == 80 )
       or ( lc( $protocol ) eq 'https' && $port == 443 );
    }
    return $url if $base;
    $url .= $script_name;
  }
  elsif ( $relative ) {
    ( $url ) = $script_name =~ m!([^/]+)$!;
  }
  elsif ( $absolute ) {
    $url = $script_name;
  }
  $url .= $path if $path_info and defined $path;
  $url .= "?" . $self->query_string if $query and $self->query_string;
  $url = '' unless defined $url;
  $url
   =~ s/([^a-zA-Z0-9_.%;&?\/\\:+=~-])/uc sprintf("%%%02x",ord($1))/eg;
  return $url;
}

sub self_url {
  my ( $self, @params ) = @_;
  return $self->url(
    '-path_info' => 1,
    '-query'     => 1,
    '-full'      => 1,
    @params
  );
}

sub state { self_url( @_ ) }    # CGI.pm synonym routine

1;

