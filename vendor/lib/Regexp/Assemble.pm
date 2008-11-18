# Regexp::Assemple.pm
#
# Copyright (c) 2004-2008 David Landgren
# All rights reserved

package Regexp::Assemble;

use vars qw/$VERSION $have_Storable $Current_Lexer $Default_Lexer $Single_Char $Always_Fail/;
$VERSION = '0.34';

=head1 NAME

Regexp::Assemble - Assemble multiple Regular Expressions into a single RE

=head1 VERSION

This document describes version 0.34 of Regexp::Assemble, released
2008-06-17.

=head1 SYNOPSIS

  use Regexp::Assemble;
  
  my $ra = Regexp::Assemble->new;
  $ra->add( 'ab+c' );
  $ra->add( 'ab+-' );
  $ra->add( 'a\w\d+' );
  $ra->add( 'a\d+' );
  print $ra->re; # prints a(?:\w?\d+|b+[-c])

=head1 DESCRIPTION

Regexp::Assemble takes an arbitrary number of regular expressions
and assembles them into a single regular expression (or RE) that
matches all that the individual REs match.

As a result, instead of having a large list of expressions to loop
over, a target string only needs to be tested against one expression.
This is interesting when you have several thousand patterns to deal
with. Serious effort is made to produce the smallest pattern possible.

It is also possible to track the original patterns, so that you can
determine which, among the source patterns that form the assembled
pattern, was the one that caused the match to occur.

You should realise that large numbers of alternations are processed
in perl's regular expression engine in O(n) time, not O(1). If you
are still having performance problems, you should look at using a
trie. Note that Perl's own regular expression engine will implement
trie optimisations in perl 5.10 (they are already available in
perl 5.9.3 if you want to try them out). C<Regexp::Assemble> will
do the right thing when it knows it's running on a a trie'd perl.
(At least in some version after this one).

Some more examples of usage appear in the accompanying README. If
that file isn't easy to access locally, you can find it on a web
repository such as
L<http://search.cpan.org/dist/Regexp-Assemble/README> or
L<http://cpan.uwinnipeg.ca/htdocs/Regexp-Assemble/README.html>.

=cut

use strict;

use constant DEBUG_ADD  => 1;
use constant DEBUG_TAIL => 2;
use constant DEBUG_LEX  => 4;
use constant DEBUG_TIME => 8;

# The following patterns were generated with eg/naive
$Default_Lexer = qr/(?![[(\\]).(?:[*+?]\??|\{\d+(?:,\d*)?\}\??)?|\\(?:[bABCEGLQUXZ]|[lu].|(?:[^\w]|[aefnrtdDwWsS]|c.|0\d{2}|x(?:[\da-fA-F]{2}|{[\da-fA-F]{4}})|N\{\w+\}|[Pp](?:\{\w+\}|.))(?:[*+?]\??|\{\d+(?:,\d*)?\}\??)?)|\[.*?(?<!\\)\](?:[*+?]\??|\{\d+(?:,\d*)?\}\??)?|\(.*?(?<!\\)\)(?:[*+?]\??|\{\d+(?:,\d*)?\}\??)?/; # ]) restore equilibrium

$Single_Char   = qr/^(?:\\(?:[aefnrtdDwWsS]|c.|[^\w\/{|}-]|0\d{2}|x(?:[\da-fA-F]{2}|{[\da-fA-F]{4}}))|[^\$^])$/;

# the pattern to return when nothing has been added (and thus not match anything)
$Always_Fail = "^\\b\0";

=head1 METHODS

=over 8

=item new

Creates a new C<Regexp::Assemble> object. The following optional
key/value parameters may be employed. All keys have a corresponding
method that can be used to change the behaviour later on. As a
general rule, especially if you're just starting out, you don't
have to bother with any of these.

B<anchor_*>, a family of optional attributes that allow anchors
(C<^>, C<\b>, C<\Z>...) to be added to the resulting pattern.

B<flags>, sets the C<imsx> flags to add to the assembled regular
expression.  Warning: no error checking is done, you should ensure
that the flags you pass are understood by the version of Perl you
are using. B<modifiers> exists as an alias, for users familiar
with L<Regexp::List>.

B<chomp>, controls whether the pattern should be chomped before being
lexed. Handy if you are reading patterns from a file. By default, 
C<chomp>ing is performed (this behaviour changed as of version 0.24,
prior versions did not chomp automatically).
See also the C<file> attribute and the C<add_file> method.

B<file>, slurp the contents of the specified file and add them
to the assembly. Multiple files may be processed by using a list.

  my $r = Regexp::Assemble->new(file => 're.list');

  my $r = Regexp::Assemble->new(file => ['re.1', 're.2']);

If you really don't want chomping to occur, you will have to set
the C<chomp> attribute to 0 (zero). You may also want to look at
the C<input_record_separator> attribute, as well.

B<input_record_separator>, controls what constitutes a record
separator when using the C<file> attribute or the C<add_file>
method. May be abbreviated to B<rs>. See the C<$/> variable in
L<perlvar>.

B<lookahead>, controls whether the pattern should contain zero-width
lookahead assertions (For instance: (?=[abc])(?:bob|alice|charles).
This is not activated by default, because in many circumstances the
cost of processing the assertion itself outweighs the benefit of
its faculty for short-circuiting a match that will fail. This is
sensitive to the probability of a match succeeding, so if you're
worried about performance you'll have to benchmark a sample population
of targets to see which way the benefits lie.

B<track>, controls whether you want know which of the initial
patterns was the one that matched. See the C<matched> method for
more details. Note for version 5.8 of Perl and below, in this mode
of operation YOU SHOULD BE AWARE OF THE SECURITY IMPLICATIONS that
this entails. Perl 5.10 does not suffer from any such restriction.

B<indent>, the number of spaces used to indent nested grouping of
a pattern. Use this to produce a pretty-printed pattern. See the
C<as_string> method for a more detailed explanation.

B<pre_filter>, allows you to add a callback to enable sanity checks
on the pattern being loaded. This callback is triggered before the
pattern is split apart by the lexer. In other words, it operates
on the entire pattern. If you are loading patterns from a file,
this would be an appropriate place to remove comments.

B<filter>, allows you to add a callback to enable sanity checks on
the pattern being loaded. This callback is triggered after the
pattern has been split apart by the lexer.

B<unroll_plus>, controls whether to unroll, for example, C<x+> into
C<x>, C<x*>, which may allow additional reductions in the
resulting assembled pattern.

B<reduce>, controls whether tail reduction occurs or not. If set,
patterns like C<a(?:bc+d|ec+d)> will be reduced to C<a[be]c+d>.
That is, the end of the pattern in each part of the b... and d...
alternations is identical, and hence is hoisted out of the alternation
and placed after it. On by default. Turn it off if you're really
pressed for short assembly times.

B<lex>, specifies the pattern used to lex the input lines into
tokens. You could replace the default pattern by a more sophisticated
version that matches arbitrarily nested parentheses, for example.

B<debug>, controls whether copious amounts of output is produced
during the loading stage or the reducing stage of assembly.

  my $ra = Regexp::Assemble->new;
  my $rb = Regexp::Assemble->new( chomp => 1, debug => 3 );

B<mutable>, controls whether new patterns can be added to the object
after the assembled pattern is generated. DEPRECATED.

This method/attribute will be removed in a future release. It doesn't
really serve any purpose, and may be more effectively replaced by
cloning an existing C<Regexp::Assemble> object and spinning out a
pattern from that instead.

A more detailed explanation of these attributes follows.

=cut

sub new {
    my $class = shift;
    my %args  = @_;

    my $anc;
    for $anc (qw(word line string)) {
        if (exists $args{"anchor_$anc"}) {
            my $val = delete $args{"anchor_$anc"};
            for my $anchor ("anchor_${anc}_begin", "anchor_${anc}_end") {
                $args{$anchor} = $val unless exists $args{$anchor};
            }
        }
    }

    # anchor_string_absolute sets anchor_string_begin and anchor_string_end_absolute
    if (exists $args{anchor_string_absolute}) {
        my $val = delete $args{anchor_string_absolute};
        for my $anchor (qw(anchor_string_begin anchor_string_end_absolute)) {
            $args{$anchor} = $val unless exists $args{$anchor};
        }
    }

    exists $args{$_} or $args{$_} = 0 for qw(
        anchor_word_begin
        anchor_word_end
        anchor_line_begin
        anchor_line_end
        anchor_string_begin
        anchor_string_end
        anchor_string_end_absolute
        debug
        dup_warn
        indent
        lookahead
        mutable
        track
        unroll_plus
    );

    exists $args{$_} or $args{$_} = 1 for qw(
        fold_meta_pairs
        reduce
        chomp
    );

    @args{qw(re str path)} = (undef, undef, []);

    $args{flags} ||= delete $args{modifiers} || '';
    $args{lex}     = $Current_Lexer if defined $Current_Lexer;

    my $self = bless \%args, $class;

    if ($self->_debug(DEBUG_TIME)) {
        $self->_init_time_func();
        $self->{_begin_time} = $self->{_time_func}->();
    }
    $self->{input_record_separator} = delete $self->{rs}
        if exists $self->{rs};
    exists $self->{file} and $self->add_file($self->{file});

    return $self;
}

sub _init_time_func {
    my $self = shift;
    return if exists $self->{_time_func};

    # attempt to improve accuracy
    if (!defined($self->{_use_time_hires})) {
        eval {require Time::HiRes};
        $self->{_use_time_hires} = $@;
    }
    $self->{_time_func} = length($self->{_use_time_hires}) > 0
        ? sub { time }
        : \&Time::HiRes::time
    ;
}

=item clone

Clones the contents of a Regexp::Assemble object and creates a new
object (in other words it performs a deep copy).

If the Storable module is installed, its dclone method will be used,
otherwise the cloning will be performed using a pure perl approach.

You can use this method to take a snapshot of the patterns that have
been added so far to an object, and generate an assembly from the
clone. Additional patterns may to be added to the original object
afterwards.

  my $re = $main->clone->re();
  $main->add( 'another-pattern-\\d+' );

=cut

sub clone {
    my $self = shift;
    my $clone;
    my @attr = grep {$_ ne 'path'} keys %$self;
    @{$clone}{@attr} = @{$self}{@attr};
    $clone->{path}   = _path_clone($self->_path);
    bless $clone, ref($self);
}

=item add(LIST)

Takes a string, breaks it apart into a set of tokens (respecting
meta characters) and inserts the resulting list into the C<R::A>
object. It uses a naive regular expression to lex the string
that may be fooled complex expressions (specifically, it will
fail to lex nested parenthetical expressions such as
C<ab(cd(ef)?gh)ij> correctly). If this is the case, the end of
the string will not be tokenised correctly and returned as one
long string.

On the one hand, this may indicate that the patterns you are
trying to feed the C<R::A> object are too complex. Simpler
patterns might allow the algorithm to work more effectively and
perform more reductions in the resulting pattern.

On the other hand, you can supply your own pattern to perform the
lexing if you need. The test suite contains an example of a lexer
pattern that will match one level of nested parentheses.

Note that there is an internal optimisation that will bypass a
much of the lexing process. If a string contains no C<\>
(backslash), C<[> (open square bracket), C<(> (open paren),
C<?> (question mark), C<+> (plus), C<*> (star) or C<{> (open
curly), a character split will be performed directly.

A list of strings may be supplied, thus you can pass it a file
handle of a file opened for reading:

    $re->add( '\d+-\d+-\d+-\d+\.example\.com' );
    $re->add( <IN> );

If the file is very large, it may be more efficient to use a
C<while> loop, to read the file line-by-line:

    $re->add($_) while <IN>;

The C<add> method will chomp the lines automatically. If you
do not want this to occur (you want to keep the record
separator), then disable C<chomp>ing.

    $re->chomp(0);
    $re->add($_) while <IN>;

This method is chainable.

=cut

sub _fastlex {
    my $self   = shift;
    my $record = shift;
    my $len    = 0;
    my @path   = ();
    my $case   = '';
    my $qm     = '';

    my $debug       = $self->{debug} & DEBUG_LEX;
    my $unroll_plus = $self->{unroll_plus};

    my $token;
    my $qualifier;
    $debug and print "# _lex <$record>\n";
    my $modifier        = q{(?:[*+?]\\??|\\{(?:\\d+(?:,\d*)?|,\d+)\\}\\??)?};
    my $class_matcher   = qr/\[(?:\[:[a-z]+:\]|\\?.)*?\]/;
    my $paren_matcher   = qr/\(.*?(?<!\\)\)$modifier/;
    my $misc_matcher    = qr/(?:(c)(.)|(0)(\d{2}))($modifier)/;
    my $regular_matcher = qr/([^\\[(])($modifier)/;
    my $qm_matcher      = qr/(\\?.)/;

    my $matcher = $regular_matcher;
    {
        if ($record =~ /\G$matcher/gc) {
            # neither a \\ nor [ nor ( followed by a modifer
            if ($1 eq '\\E') {
                $debug and print "#   E\n";
                $case = $qm = '';
                $matcher = $regular_matcher;
                redo;
            }
            elsif ($qm and ($1 eq '\\L' or $1 eq '\\U')) {
                $debug and print "#  ignore \\L, \\U\n";
                redo;
            }
            $token = $1;
            $qualifier = defined $2 ? $2 : '';
            $debug and print "#  token <$token> <$qualifier>\n";
            if ($qm) {
                $token = quotemeta($token);
                $token =~ s/^\\([^\w$()*+.?@\[\\\]^|{}\/])$/$1/;
            }
            else {
                $token =~ s{\A([][{}*+?@\\/])\Z}{\\$1};
            }
            if ($unroll_plus and $qualifier =~ s/\A\+(\?)?\Z/*/) {
                $1 and $qualifier .= $1;
                $debug and print " unroll <$token><$token><$qualifier>\n";
                $case and $token = $case eq 'L' ? lc($token) : uc($token);
                push @path, $token, "$token$qualifier";
            }
            else {
                $debug and print " clean <$token>\n";
                push @path,
                      $case eq 'L' ? lc($token).$qualifier
                    : $case eq 'U' ? uc($token).$qualifier
                    :                   $token.$qualifier
                    ;
            }
            redo;
        }

        elsif ($record =~ /\G\\/gc) {
            $debug and print "#  backslash\n";
            # backslash
            if ($record =~ /\G([sdwSDW])($modifier)/gc) {
                ($token, $qualifier) = ($1, $2);
                $debug and print "#   meta <$token> <$qualifier>\n";
                push @path, ($unroll_plus and $qualifier =~ s/\A\+(\?)?\Z/*/)
                    ? ("\\$token", "\\$token$qualifier" . (defined $1 ? $1 : ''))
                    : "\\$token$qualifier";
            }
            elsif ($record =~ /\Gx([\da-fA-F]{2})($modifier)/gc) {
                $debug and print "#   x $1\n";
                $token = quotemeta(chr(hex($1)));
                $qualifier = $2;
                $debug and print "#  cooked <$token>\n";
                $token =~ s/^\\([^\w$()*+.?\[\\\]^|{\/])$/$1/; # } balance
                $debug and print "#   giving <$token>\n";
                push @path, ($unroll_plus and $qualifier =~ s/\A\+(\?)?\Z/*/)
                    ? ($token, "$token$qualifier" . (defined $1 ? $1 : ''))
                    : "$token$qualifier";
            }
            elsif ($record =~ /\GQ/gc) {
                $debug and print "#   Q\n";
                $qm = 1;
                $matcher = $qm_matcher;
            }
            elsif ($record =~ /\G([LU])/gc) {
                $debug and print "#   case $1\n";
                $case = $1;
            }
            elsif ($record =~ /\GE/gc) {
                $debug and print "#   E\n";
                $case = $qm = '';
                $matcher = $regular_matcher;
            }
            elsif ($record =~ /\G([lu])(.)/gc) {
                $debug and print "#   case $1 to <$2>\n";
                push @path, $1 eq 'l' ? lc($2) : uc($2);
            }
            elsif (my @arg = grep {defined} $record =~ /\G$misc_matcher/gc) {
                if ($] < 5.007) {
                    my $len = 0;
                    $len += length($_) for @arg;
                    $debug and print "#  pos ", pos($record), " fixup add $len\n";
                    pos($record) = pos($record) + $len;
                }
                my $directive = shift @arg;
                if ($directive eq 'c') {
                    $debug and print "#  ctrl <@arg>\n";
                    push @path, "\\c" . uc(shift @arg);
                }
                else { # elsif ($directive eq '0') {
                    $debug and print "#  octal <@arg>\n";
                    my $ascii = oct(shift @arg);
                    push @path, ($ascii < 32)
                        ? "\\c" . chr($ascii+64)
                        : chr($ascii)
                    ;
                }
                $path[-1] .= join( '', @arg ); # if @arg;
                redo;
            }
            elsif ($record =~ /\G(.)/gc) {
                $token = $1;
                $token =~ s{[AZabefnrtz\[\]{}()\\\$*+.?@|/^]}{\\$token};
                $debug and print "#   meta <$token>\n";
                push @path, $token;
            }
            else {
                $debug and print "#   ignore char at ", pos($record), " of <$record>\n";
            }
            redo;
        }

        elsif ($record =~ /\G($class_matcher)($modifier)/gc) {
            # [class] followed by a modifer
            my $class     = $1;
            my $qualifier = defined $2 ? $2 : '';
            $debug and print "#  class begin <$class> <$qualifier>\n";
            if ($class =~ /\A\[\\?(.)]\Z/) {
                $class = quotemeta $1;
                $class =~ s{\A\\([!@%])\Z}{$1};
                $debug and print "#  class unwrap $class\n";
            }
            $debug and print "#  class end <$class> <$qualifier>\n";
            push @path, ($unroll_plus and $qualifier =~ s/\A\+(\?)?\Z/*/)
                ? ($class, "$class$qualifier" . (defined $1 ? $1 : ''))
                : "$class$qualifier";
            redo;
        }

        elsif ($record =~ /\G($paren_matcher)/gc) {
            $debug and print "#  paren <$1>\n";
            # (paren) followed by a modifer
            push @path, $1;
            redo;
        }

    }
    return \@path;
}

sub _lex {
    my $self   = shift;
    my $record = shift;
    my $len    = 0;
    my @path   = ();
    my $case   = '';
    my $qm     = '';
    my $re     = defined $self->{lex} ? $self->{lex}
        : defined $Current_Lexer ? $Current_Lexer
        : $Default_Lexer;
    my $debug  = $self->{debug} & DEBUG_LEX;
    $debug and print "# _lex <$record>\n";
    my ($token, $next_token, $diff, $token_len);
    while( $record =~ /($re)/g ) {
        $token = $1;
        $token_len = length($token);
        $debug and print "# lexed <$token> len=$token_len\n";
        if( pos($record) - $len > $token_len ) {
            $next_token = $token;
            $token = substr( $record, $len, $diff = pos($record) - $len - $token_len );
            $debug and print "#  recover <", substr( $record, $len, $diff ), "> as <$token>, save <$next_token>\n";
            $len += $diff;
        }
        $len += $token_len;
        TOKEN: {
            if( substr( $token, 0, 1 ) eq '\\' ) {
                if( $token =~ /^\\([ELQU])$/ ) {
                    if( $1 eq 'E' ) {
                        $qm and $re = defined $self->{lex} ? $self->{lex}
                            : defined $Current_Lexer ? $Current_Lexer
                            : $Default_Lexer;
                        $case = $qm = '';
                    }
                    elsif( $1 eq 'Q' ) {
                        $qm = $1;
                        # switch to a more precise lexer to quotemeta individual characters
                        $re = qr/\\?./;
                    }
                    else {
                        $case = $1;
                    }
                    $debug and print "#  state change qm=<$qm> case=<$case>\n";
                    goto NEXT_TOKEN;
                }
                elsif( $token =~ /^\\([lu])(.)$/ ) {
                    $debug and print "#  apply case=<$1> to <$2>\n";
                    push @path, $1 eq 'l' ? lc($2) : uc($2);
                    goto NEXT_TOKEN;
                }
                elsif( $token =~ /^\\x([\da-fA-F]{2})$/ ) {
                    $token = quotemeta(chr(hex($1)));
                    $debug and print "#  cooked <$token>\n";
                    $token =~ s/^\\([^\w$()*+.?@\[\\\]^|{\/])$/$1/; # } balance
                    $debug and print "#   giving <$token>\n";
                }
                else {
                    $token =~ s/^\\([^\w$()*+.?@\[\\\]^|{\/])$/$1/; # } balance
                    $debug and print "#  backslashed <$token>\n";
                }
            }
            else {
                $case and $token = $case eq 'U' ? uc($token) : lc($token);
                $qm   and $token = quotemeta($token);
                $token = '\\/' if $token eq '/';
            }
            # undo quotemeta's brute-force escapades
            $qm and $token =~ s/^\\([^\w$()*+.?@\[\\\]^|{}\/])$/$1/;
            $debug and print "#   <$token> case=<$case> qm=<$qm>\n";
            push @path, $token;

            NEXT_TOKEN:
            if( defined $next_token ) {
                $debug and print "#   redo <$next_token>\n";
                $token = $next_token;
                $next_token = undef;
                redo TOKEN;
            }
        }
    }
    if( $len < length($record) ) {
        # NB: the remainder only arises in the case of degenerate lexer,
        # and if \Q is operative, the lexer will have been switched to
        # /\\?./, which means there can never be a remainder, so we
        # don't have to bother about quotemeta. In other words:
        # $qm will never be true in this block.
        my $remain = substr($record,$len); 
        $case and $remain = $case eq 'U' ? uc($remain) : lc($remain);
        $debug and print "#   add remaining <$remain> case=<$case> qm=<$qm>\n";
        push @path, $remain;
    }
    $debug and print "# _lex out <@path>\n";
    return \@path;
}

sub add {
    my $self = shift;
    my $record;
    my $debug  = $self->{debug} & DEBUG_LEX;
    while( defined( $record = shift @_ )) {
        CORE::chomp($record) if $self->{chomp};
        next if $self->{pre_filter} and not $self->{pre_filter}->($record);
        $debug and print "# add <$record>\n";
        $self->{stats_raw} += length $record;
        my $list = $record =~ /[+*?(\\\[{]/ # }]) restore equilibrium
            ? $self->{lex} ? $self->_lex($record) : $self->_fastlex($record)
            : [split //, $record]
        ;
        next if $self->{filter} and not $self->{filter}->(@$list);
        $self->_insertr( $list );
    }
    return $self;
}

=item add_file(FILENAME [...])

Takes a list of file names. Each file is opened and read
line by line. Each line is added to the assembly.

  $r->add_file( 'file.1', 'file.2' );

If a file cannot be opened, the method will croak. If you cannot
afford to let this happen then you should wrap the call in a C<eval>
block.

Chomping happens automatically unless you the C<chomp(0)> method
to disable it. By default, input lines are read according to the
value of the C<input_record_separator> attribute (if defined), and
will otherwise fall back to the current setting of the system C<$/>
variable. The record separator may also be specified on each
call to C<add_file>. Internally, the routine C<local>ises the
value of C<$/> to whatever is required, for the duration of the
call.

An alternate calling mechanism using a hash reference is
available.  The recognised keys are:

=over 4

=item file

Reference to a list of file names, or the name of a single
file.

  $r->add_file({file => ['file.1', 'file.2', 'file.3']});
  $r->add_file({file => 'file.n'});

=item input_record_separator

If present, indicates what constitutes a line

  $r->add_file({file => 'data.txt', input_record_separator => ':' });

=item rs

An alias for input_record_separator (mnemonic: same as the
English variable names).

=back

  $r->add_file( {
    file => [ 'pattern.txt', 'more.txt' ],
    input_record_separator  => "\r\n",
  });

=cut

sub add_file {
    my $self = shift;
    my $rs;
    my @file;
    if (ref($_[0]) eq 'HASH') {
        my $arg = shift;
        $rs = $arg->{rs}
            || $arg->{input_record_separator}
            || $self->{input_record_separator}
            || $/;
        @file = ref($arg->{file}) eq 'ARRAY'
            ? @{$arg->{file}}
            : $arg->{file};
    }
    else {
        $rs   = $self->{input_record_separator} || $/;
        @file = @_;
    }
    local $/ = $rs;
    my $file;
    for $file (@file) {
        open my $fh, '<', $file or do {
            require Carp;
            Carp::croak("cannot open $file for input: $!");
        };
        while (defined (my $rec = <$fh>)) {
            $self->add($rec);
        }
        close $fh;
    }
    return $self;
}

=item insert(LIST)

Takes a list of tokens representing a regular expression and
stores them in the object. Note: you should not pass it a bare
regular expression, such as C<ab+c?d*e>. You must pass it as
a list of tokens, I<e.g.> C<('a', 'b+', 'c?', 'd*', 'e')>.

This method is chainable, I<e.g.>:

  my $ra = Regexp::Assemble->new
    ->insert( qw[ a b+ c? d* e ] )
    ->insert( qw[ a c+ d+ e* f ] );

Lexing complex patterns with metacharacters and so on can consume
a significant proportion of the overall time to build an assembly.
If you have the information available in a tokenised form, calling
C<insert> directly can be a big win.

=cut

sub insert {
    my $self = shift;
    return if $self->{filter} and not $self->{filter}->(@_);
    $self->_insertr( [@_] );
    return $self;
}

sub _insertr {
    my $self   = shift;
    my $dup    = $self->{stats_dup} || 0;
    $self->{path} = $self->_insert_path( $self->_path, $self->_debug(DEBUG_ADD), $_[0] );
    if( not defined $self->{stats_dup} or $dup == $self->{stats_dup} ) {
        ++$self->{stats_add};
        $self->{stats_cooked} += defined($_) ? length($_) : 0 for @{$_[0]};
    }
    elsif( $self->{dup_warn} ) {
        if( ref $self->{dup_warn} eq 'CODE' ) {
            $self->{dup_warn}->($self, $_[0]); 
        }
        else {
            my $pattern = join( '', @{$_[0]} );
            require Carp;
            Carp::carp("duplicate pattern added: /$pattern/");
        }
    }
    $self->{str} = $self->{re} = undef;
}

=item lexstr

Use the C<lexstr> method if you are curious to see how a pattern
gets tokenised. It takes a scalar on input, representing a pattern,
and returns a reference to an array, containing the tokenised
pattern. You can recover the original pattern by performing a
C<join>:

  my @token = $re->lexstr($pattern);
  my $new_pattern = join( '', @token );

If the original pattern contains unnecessary backslashes, or C<\x4b>
escapes, or quotemeta escapes (C<\Q>...C<\E>) the resulting pattern
may not be identical.

Call C<lexstr> does not add the pattern to the object, it is merely
for exploratory purposes. It will, however, update various statistical
counters.

=cut

sub lexstr {
    return shift->_lex(shift);
}

=item pre_filter(CODE)

Allows you to install a callback to check that the pattern being
loaded contains valid input. It receives the pattern as a whole to
be added, before it been tokenised by the lexer. It may to return
0 or C<undef> to indicate that the pattern should not be added, any
true value indicates that the contents are fine.

A filter to strip out trailing comments (marked by #):

  $re->pre_filter( sub { $_[0] =~ s/\s*#.*$//; 1 } );

A filter to ignore blank lines:

  $re->pre_filter( sub { length(shift) } );

If you want to remove the filter, pass C<undef> as a parameter.

  $ra->pre_filter(undef);

This method is chainable.

=cut

sub pre_filter {
    my $self   = shift;
    my $pre_filter = shift;
    if( defined $pre_filter and ref($pre_filter) ne 'CODE' ) {
        require Carp;
        Carp::croak("pre_filter method not passed a coderef");
    }
    $self->{pre_filter} = $pre_filter;
    return $self;
}


=item filter(CODE)

Allows you to install a callback to check that the pattern being
loaded contains valid input. It receives a list on input, after it
has been tokenised by the lexer. It may to return 0 or undef to
indicate that the pattern should not be added, any true value
indicates that the contents are fine.

If you know that all patterns you expect to assemble contain
a restricted set of of tokens (e.g. no spaces), you could do
the following:

  $ra->filter(sub { not grep { / / } @_ });

or

  sub only_spaces_and_digits {
    not grep { ![\d ] } @_
  }
  $ra->filter( \&only_spaces_and_digits );

These two examples will silently ignore faulty patterns, If you
want the user to be made aware of the problem you should raise an
error (via C<warn> or C<die>), log an error message, whatever is
best. If you want to remove a filter, pass C<undef> as a parameter.

  $ra->filter(undef);

This method is chainable.

=cut

sub filter {
    my $self   = shift;
    my $filter = shift;
    if( defined $filter and ref($filter) ne 'CODE' ) {
        require Carp;
        Carp::croak("filter method not passed a coderef");
    }
    $self->{filter} = $filter;
    return $self;
}

=item as_string

Assemble the expression and return it as a string. You may want to do
this if you are writing the pattern to a file. The following arguments
can be passed to control the aspect of the resulting pattern:

B<indent>, the number of spaces used to indent nested grouping of
a pattern. Use this to produce a pretty-printed pattern (for some
definition of "pretty"). The resulting output is rather verbose. The
reason is to ensure that the metacharacters C<(?:> and C<)> always
occur on otherwise empty lines. This allows you grep the result for an
even more synthetic view of the pattern:

  egrep -v '^ *[()]' <regexp.file>

The result of the above is quite readable. Remember to backslash the
spaces appearing in your own patterns if you wish to use an indented
pattern in an C<m/.../x> construct. Indenting is ignored if tracking
is enabled.

The B<indent> argument takes precedence over the C<indent>
method/attribute of the object.

Calling this
method will drain the internal data structure. Large numbers of patterns
can eat a significant amount of memory, and this lets perl recover the
memory used for other purposes.

If you want to reduce the pattern I<and> continue to add new patterns,
clone the object and reduce the clone, leaving the original object intact.

=cut

sub as_string {
    my $self = shift;
    if( not defined $self->{str} ) {
        if( $self->{track} ) {
            $self->{m}      = undef;
            $self->{mcount} = 0;
            $self->{mlist}  = [];
            $self->{str}    = _re_path_track($self, $self->_path, '', '');
        }
        else {
            $self->_reduce unless ($self->{mutable} or not $self->{reduce});
            my $arg  = {@_};
            $arg->{indent} = $self->{indent}
                if not exists $arg->{indent} and $self->{indent} > 0;
            if( exists $arg->{indent} and $arg->{indent} > 0 ) {
                $arg->{depth} = 0;
                $self->{str}  = _re_path_pretty($self, $self->_path, $arg);
            }
            elsif( $self->{lookahead} ) {
                $self->{str}  = _re_path_lookahead($self, $self->_path);
            }
            else {
                $self->{str}  = _re_path($self, $self->_path);
            }
        }
        if (not length $self->{str}) {
            # explicitly fail to match anything if no pattern was generated
            $self->{str} = $Always_Fail;
        }
        else {
            my $begin = 
                  $self->{anchor_word_begin}   ? '\\b'
                : $self->{anchor_line_begin}   ? '^'
                : $self->{anchor_string_begin} ? '\A'
                : ''
            ;
            my $end = 
                  $self->{anchor_word_end}            ? '\\b'
                : $self->{anchor_line_end}            ? '$'
                : $self->{anchor_string_end}          ? '\Z'
                : $self->{anchor_string_end_absolute} ? '\z'
                : ''
            ;
            $self->{str} = "$begin$self->{str}$end";
        }
        $self->{path} = [] unless $self->{mutable};
    }
    return $self->{str};
}

=item re

Assembles the pattern and return it as a compiled RE, using the
C<qr//> operator.

As with C<as_string>, calling this method will reset the internal data
structures to free the memory used in assembling the RE.

The B<indent> attribute, documented in the C<as_string> method, can be
used here (it will be ignored if tracking is enabled).

With method chaining, it is possible to produce a RE without having
a temporary C<Regexp::Assemble> object lying around, I<e.g.>:

  my $re = Regexp::Assemble->new
    ->add( q[ab+cd+e] )
    ->add( q[ac\\d+e] )
    ->add( q[c\\d+e] )
    ->re;

The C<$re> variable now contains a Regexp object that can be used
directly:

  while( <> ) {
    /$re/ and print "Something in [$_] matched\n";
  )

The C<re> method is called when the object is used in string context
(hence, within an C<m//> operator), so by and large you do not even
need to save the RE in a separate variable. The following will work
as expected:

  my $re = Regexp::Assemble->new->add( qw[ fee fie foe fum ] );
  while( <IN> ) {
    if( /($re)/ ) {
      print "Here be giants: $1\n";
    }
  }

This approach does not work with tracked patterns. The
C<match> and C<matched> methods must be used instead, see below.

=cut

sub re {
    my $self = shift;
    $self->_build_re($self->as_string(@_)) unless defined $self->{re};
    return $self->{re};
}

use overload '""' => sub {
    my $self = shift;
    return $self->{re} if $self->{re};
    $self->_build_re($self->as_string());
    return $self->{re};
};

sub _build_re {
    my $self  = shift;
    my $str   = shift;
    if( $self->{track} ) {
        use re 'eval';
        $self->{re} = length $self->{flags}
            ? qr/(?$self->{flags}:$str)/
            : qr/$str/
        ;
    }
    else {
        # how could I not repeat myself?
        $self->{re} = length $self->{flags}
            ? qr/(?$self->{flags}:$str)/
            : qr/$str/
        ;
    }
}

=item match(SCALAR)

The following information applies to Perl 5.8 and below. See
the section that follows for information on Perl 5.10.

If pattern tracking is in use, you must C<use re 'eval'> in order
to make things work correctly. At a minimum, this will make your
code look like this:

    my $did_match = do { use re 'eval'; $target =~ /$ra/ }
    if( $did_match ) {
        print "matched ", $ra->matched, "\n";
    }

(The main reason is that the C<$^R> variable is currently broken
and an ugly workaround that runs some Perl code during the match
is required, in order to simulate what C<$^R> should be doing. See
Perl bug #32840 for more information if you are curious. The README
also contains more information). This bug has been fixed in 5.10.

The important thing to note is that with C<use re 'eval'>, THERE
ARE SECURITY IMPLICATIONS WHICH YOU IGNORE AT YOUR PERIL. The problem
is this: if you do not have strict control over the patterns being
fed to C<Regexp::Assemble> when tracking is enabled, and someone
slips you a pattern such as C</^(?{system 'rm -rf /'})/> and you
attempt to match a string against the resulting pattern, you will
know Fear and Loathing.

What is more, the C<$^R> workaround means that that tracking does
not work if you perform a bare C</$re/> pattern match as shown
above. You have to instead call the C<match> method, in order to
supply the necessary context to take care of the tracking housekeeping
details.

   if( defined( my $match = $ra->match($_)) ) {
       print "  $_ matched by $match\n";
   }

In the case of a successful match, the original matched pattern
is returned directly. The matched pattern will also be available
through the C<matched> method.

(Except that the above is not true for 5.6.0: the C<match> method
returns true or undef, and the C<matched> method always returns
undef).

If you are capturing parts of the pattern I<e.g.> C<foo(bar)rat>
you will want to get at the captures. See the C<mbegin>, C<mend>,
C<mvar> and C<capture> methods. If you are not using captures
then you may safely ignore this section.

In 5.10, since the bug concerning C<$^R> has been resolved, there
is no need to use C<re 'eval'> and the assembled pattern does
not require any Perl code to be executed during the match.

=cut

sub match {
    my $self = shift;
    my $target = shift;
    $self->_build_re($self->as_string(@_)) unless defined $self->{re};
    $self->{m}    = undef;
    $self->{mvar} = [];
    if( not $target =~ /$self->{re}/ ) {
        $self->{mbegin} = [];
        $self->{mend}   = [];
        return undef;
    }
    $self->{m}      = $^R if $] >= 5.009005;
    $self->{mbegin} = _path_copy([@-]);
    $self->{mend}   = _path_copy([@+]);
    my $n = 0;
    for( my $n = 0; $n < @-; ++$n ) {
        push @{$self->{mvar}}, substr($target, $-[$n], $+[$n] - $-[$n])
            if defined $-[$n] and defined $+[$n];
    }
    if( $self->{track} ) {
        return defined $self->{m} ? $self->{mlist}[$self->{m}] : 1;
    }
    else {
        return 1;
    }
}

=item source

When using tracked mode, after a successful match is made, returns
the original source pattern that caused the match. In Perl 5.10,
the C<$^R> variable can be used to as an index to fetch the correct
pattern from the object.

If no successful match has been performed, or the object is not in
tracked mode, this method returns C<undef>.

  my $r = Regexp::Assemble->new->track(1)->add(qw(foo? bar{2} [Rr]at));

  for my $w (qw(this food is rather barren)) {
    if ($w =~ /$r/) {
      print "$w matched by ", $r->source($^R), $/;
    }
    else {
      print "$w no match\n";
    }
  }

=cut

sub source {
    my $self = shift;
    return unless $self->{track};
    defined($_[0]) and return $self->{mlist}[$_[0]];
    return unless defined $self->{m};
    return $self->{mlist}[$self->{m}];
}

=item mbegin

This method returns a copy of C<@-> at the moment of the
last match. You should ordinarily not need to bother with
this, C<mvar> should be able to supply all your needs.

=cut

sub mbegin {
    my $self = shift;
    return exists $self->{mbegin} ? $self->{mbegin} : [];
}

=item mend

This method returns a copy of C<@+> at the moment of the
last match.

=cut

sub mend {
    my $self = shift;
    return exists $self->{mend} ? $self->{mend} : [];
}

=item mvar(NUMBER)

The C<mvar> method returns the captures of the last match.
C<mvar(1)> corresponds to $1, C<mvar(2)> to $2, and so on.
C<mvar(0)> happens to return the target string matched,
as a byproduct of walking down the C<@-> and C<@+> arrays
after the match.

If called without a parameter, C<mvar> will return a
reference to an array containing all captures.

=cut

sub mvar {
    my $self = shift;
    return undef unless exists $self->{mvar};
    return defined($_[0]) ? $self->{mvar}[$_[0]] : $self->{mvar};
}

=item capture

The C<capture> method returns the the captures of the last
match as an array. Unlink C<mvar>, this method does not
include the matched string. It is equivalent to getting an
array back that contains C<$1, $2, $3, ...>.

If no captures were found in the match, an empty array is
returned, rather than C<undef>. You are therefore guaranteed
to be able to use C<< for my $c ($re->capture) { ... >>
without have to check whether anything was captured.

=cut

sub capture {
    my $self = shift;
    if( $self->{mvar} ) {
        my @capture = @{$self->{mvar}};
        shift @capture;
        return @capture;
    }
    return ();
}

=item matched

If pattern tracking has been set, via the C<track> attribute,
or through the C<track> method, this method will return the
original pattern of the last successful match. Returns undef
match has yet been performed, or tracking has not been enabled.

See below in the NOTES section for additional subtleties of
which you should be aware of when tracking patterns.

Note that this method is not available in 5.6.0, due to
limitations in the implementation of C<(?{...})> at the time.

=cut

sub matched {
    my $self = shift;
    return defined $self->{m} ? $self->{mlist}[$self->{m}] : undef;
}

=back

=head2 Statistics/Reporting routines

=over 8

=item stats_add

Returns the number of patterns added to the assembly (whether
by C<add> or C<insert>). Duplicate patterns are not included
in this total.

=cut

sub stats_add {
    my $self = shift;
    return $self->{stats_add} || 0;
}

=item stats_dup

Returns the number of duplicate patterns added to the assembly.
If non-zero, this may be a sign that something is wrong with
your data (or at the least, some needless redundancy). This may
occur when you have two patterns (for instance, C<a\-b> and
C<a-b>) which map to the same result.

=cut

sub stats_dup {
    my $self = shift;
    return $self->{stats_dup} || 0;
}

=item stats_raw

Returns the raw number of bytes in the patterns added to the
assembly. This includes both original and duplicate patterns.
For instance, adding the two patterns C<ab> and C<ab> will
count as 4 bytes.

=cut

sub stats_raw {
    my $self = shift;
    return $self->{stats_raw} || 0;
}

=item stats_cooked

Return the true number of bytes added to the assembly. This
will not include duplicate patterns. Furthermore, it may differ
from the raw bytes due to quotemeta treatment. For instance,
C<abc\,def> will count as 7 (not 8) bytes, because C<\,> will
be stored as C<,>. Also, C<\Qa.b\E> is 7 bytes long, however,
after the quotemeta directives are processed, C<a\.b> will be
stored, for a total of 4 bytes.

=cut

sub stats_cooked {
    my $self = shift;
    return $self->{stats_cooked} || 0;
}

=item stats_length

Returns the length of the resulting assembled expression.
Until C<as_string> or C<re> have been called, the length
will be 0 (since the assembly will have not yet been
performed). The length includes only the pattern, not the
additional (C<(?-xism...>) fluff added by the compilation.

=cut

sub stats_length {
    my $self = shift;
    return (defined $self->{str} and $self->{str} ne $Always_Fail) ? length $self->{str} : 0;
}

=item dup_warn(NUMBER|CODEREF)

Turns warnings about duplicate patterns on or off. By
default, no warnings are emitted. If the method is
called with no parameters, or a true parameter,
the object will carp about patterns it has
already seen. To turn off the warnings, use 0 as a
parameter.

  $r->dup_warn();

The method may also be passed a code block. In this case
the code will be executed and it will receive a reference
to the object in question, and the lexed pattern.

  $r->dup_warn(
    sub {
      my $self = shift;
      print $self->stats_add, " patterns added at line $.\n",
          join( '', @_ ), " added previously\n";
    }
  )

=cut

sub dup_warn {
    my $self = shift;
    $self->{dup_warn} = defined($_[0]) ? $_[0] : 1;
    return $self;
}

=back

=head2 Anchor routines

Suppose you wish to assemble a series of patterns that all begin
with C<^>  and end with C<$> (anchor pattern to the beginning and
end of line). Rather than add the anchors to each and every pattern
(and possibly forget to do so when a new entry is added), you may
specify the anchors in the object, and they will appear in the
resulting pattern, and you no longer need to (or should) put them
in your source patterns. For example, the two following snippets
will produce identical patterns:

  $r->add(qw(^this ^that ^them))->as_string;

  $r->add(qw(this that them))->anchor_line_begin->as_string;

  # both techniques will produce ^th(?:at|em|is)

All anchors are possible word (C<\b>) boundaries, line
boundaries (C<^> and C<$>) and string boundaries (C<\A>
and C<\Z> (or C<\z> if you absolutely need it)).

The shortcut C<anchor_I<mumble>> implies both
C<anchor_I<mumble>_begin> C<anchor_I<mumble>_end> 
is also available. If different anchors are specified
the most specific anchor wins. For instance, if both
C<anchor_word_begin> and C<anchor_line_begin> are
specified, C<anchor_word_begin> takes precedence.

All the anchor methods are chainable.

=over 8

=item anchor_word_begin

The resulting pattern will be prefixed with a C<\b>
word boundary assertion when the value is true. Set
to 0 to disable.

  $r->add('pre')->anchor_word_begin->as_string;
  # produces '\bpre'

=cut

sub anchor_word_begin {
    my $self = shift;
    $self->{anchor_word_begin} = defined($_[0]) ? $_[0] : 1;
    return $self;
}

=item anchor_word_end

The resulting pattern will be suffixed with a C<\b>
word boundary assertion when the value is true. Set
to 0 to disable.

  $r->add(qw(ing tion))
    ->anchor_word_end
    ->as_string; # produces '(?:tion|ing)\b'

=cut

sub anchor_word_end {
    my $self = shift;
    $self->{anchor_word_end} = defined($_[0]) ? $_[0] : 1;
    return $self;
}

=item anchor_word

The resulting pattern will be have C<\b>
word boundary assertions at the beginning and end
of the pattern when the value is true. Set
to 0 to disable.

  $r->add(qw(cat carrot)
    ->anchor_word(1)
    ->as_string; # produces '\bca(?:rro)t\b'

=cut

sub anchor_word {
    my $self  = shift;
    my $state = shift;
    $self->anchor_word_begin($state)->anchor_word_end($state);
    return $self;
}

=item anchor_line_begin

The resulting pattern will be prefixed with a C<^>
line boundary assertion when the value is true. Set
to 0 to disable.

  $r->anchor_line_begin;
  # or
  $r->anchor_line_begin(1);

=cut

sub anchor_line_begin {
    my $self = shift;
    $self->{anchor_line_begin} = defined($_[0]) ? $_[0] : 1;
    return $self;
}

=item anchor_line_end

The resulting pattern will be suffixed with a C<$>
line boundary assertion when the value is true. Set
to 0 to disable.

  # turn it off
  $r->anchor_line_end(0);

=cut

sub anchor_line_end {
    my $self = shift;
    $self->{anchor_line_end} = defined($_[0]) ? $_[0] : 1;
    return $self;
}

=item anchor_line

The resulting pattern will be have the C<^> and C<$>
line boundary assertions at the beginning and end
of the pattern, respectively, when the value is true. Set
to 0 to disable.

  $r->add(qw(cat carrot)
    ->anchor_line
    ->as_string; # produces '^ca(?:rro)t$'

=cut

sub anchor_line {
    my $self  = shift;
    my $state = shift;
    $self->anchor_line_begin($state)->anchor_line_end($state);
    return $self;
}

=item anchor_string_begin

The resulting pattern will be prefixed with a C<\A>
string boundary assertion when the value is true. Set
to 0 to disable.

  $r->anchor_string_begin(1);

=cut

sub anchor_string_begin {
    my $self = shift;
    $self->{anchor_string_begin} = defined($_[0]) ? $_[0] : 1;
    return $self;
}

=item anchor_string_end

The resulting pattern will be suffixed with a C<\Z>
string boundary assertion when the value is true. Set
to 0 to disable.

  # disable the string boundary end anchor
  $r->anchor_string_end(0);

=cut

sub anchor_string_end {
    my $self = shift;
    $self->{anchor_string_end} = defined($_[0]) ? $_[0] : 1;
    return $self;
}

=item anchor_string_end_absolute

The resulting pattern will be suffixed with a C<\z>
string boundary assertion when the value is true. Set
to 0 to disable.

  # disable the string boundary absolute end anchor
  $r->anchor_string_end_absolute(0);

If you don't understand the difference between
C<\Z> and C<\z>, the former will probably do what
you want.

=cut

sub anchor_string_end_absolute {
    my $self = shift;
    $self->{anchor_string_end_absolute} = defined($_[0]) ? $_[0] : 1;
    return $self;
}

=item anchor_string

The resulting pattern will be have the C<\A> and C<\Z>
string boundary assertions at the beginning and end
of the pattern, respectively, when the value is true. Set
to 0 to disable.

  $r->add(qw(cat carrot)
    ->anchor_string
    ->as_string; # produces '\Aca(?:rro)t\Z'

=cut

sub anchor_string {
    my $self  = shift;
    my $state = defined($_[0]) ? $_[0] : 1;
    $self->anchor_string_begin($state)->anchor_string_end($state);
    return $self;
}

=item anchor_string_absolute

The resulting pattern will be have the C<\A> and C<\z>
string boundary assertions at the beginning and end
of the pattern, respectively, when the value is true. Set
to 0 to disable.

  $r->add(qw(cat carrot)
    ->anchor_string_absolute
    ->as_string; # produces '\Aca(?:rro)t\z'

=cut

sub anchor_string_absolute {
    my $self  = shift;
    my $state = defined($_[0]) ? $_[0] : 1;
    $self->anchor_string_begin($state)->anchor_string_end_absolute($state);
    return $self;
}

=back

=over 8

=item debug(NUMBER)

Turns debugging on or off. Statements are printed
to the currently selected file handle (STDOUT by default).
If you are already using this handle, you will have to
arrange to select an output handle to a file of your own
choosing, before call the C<add>, C<as_string> or C<re>)
functions, otherwise it will scribble all over your
carefully formatted output.

=over 8

=item 0

Off. Turns off all debugging output.

=item 1

Add. Trace the addition of patterns.

=item 2

Reduce. Trace the process of reduction and assembly.

=item 4

Lex. Trace the lexing of the input patterns into its constituent
tokens.

=item 8

Time. Print to STDOUT the time taken to load all the patterns. This is
nothing more than the difference between the time the object was
instantiated and the time reduction was initiated.

  # load=<num>

Any lengthy computation performed in the client code will be reflected
in this value. Another line will be printed after reduction is
complete.

  # reduce=<num>

The above output lines will be changed to C<load-epoch> and
C<reduce-epoch> if the internal state of the object is corrupted
and the initial timestamp is lost.

The code attempts to load L<Time::HiRes> in order to report fractional
seconds. If this is not successful, the elapsed time is displayed
in whole seconds.

=back

Values can be added (or or'ed together) to trace everything

  $r->debug(7)->add( '\\d+abc' );

Calling C<debug> with no arguments turns debugging off.

=cut

sub debug {
    my $self = shift;
    $self->{debug} = defined($_[0]) ? $_[0] : 0;
    if ($self->_debug(DEBUG_TIME)) {
        # hmm, debugging time was switched on after instantiation
        $self->_init_time_func;
        $self->{_begin_time} = $self->{_time_func}->();
    }
    return $self;
}

=item dump

Produces a synthetic view of the internal data structure. How
to interpret the results is left as an exercise to the reader.

  print $r->dump;

=cut

sub dump {
    return _dump($_[0]->_path);
}

=item chomp(0|1)

Turns chomping on or off. 

IMPORTANT: As of version 0.24, chomping is now on by default as it
makes C<add_file> Just Work. The only time you may run into trouble
is with C<add("\\$/")>. So don't do that, or else explicitly turn
off chomping.

To avoid incorporating (spurious)
record separators (such as "\n" on Unix) when reading from a file, 
C<add()> C<chomp>s its input. If you don't want this to happen,
call C<chomp> with a false value.

  $re->chomp(0); # really want the record separators
  $re->add(<DATA>);

=cut

sub chomp {
    my $self = shift;
    $self->{chomp} = defined($_[0]) ? $_[0] : 1;
    return $self;
}

=item fold_meta_pairs(NUMBER)

Determines whether C<\s>, C<\S> and C<\w>, C<\W> and C<\d>, C<\D>
are folded into a C<.> (dot). Folding happens by default (for
reasons of backwards compatibility, even though it is wrong when
the C</s> expression modifier is active).

Call this method with a false value to prevent this behaviour (which
is only a problem when dealing with C<\n> if the C</s> expression
modifier is also set).

  $re->add( '\\w', '\\W' );
  my $clone = $re->clone;

  $clone->fold_meta_pairs(0);
  print $clone->as_string; # prints '.'
  print $re->as_string;    # print '[\W\w]'

=cut

sub fold_meta_pairs {
    my $self = shift;
    $self->{fold_meta_pairs} = defined($_[0]) ? $_[0] : 1;
    return $self;
}

=item indent(NUMBER)

Sets the level of indent for pretty-printing nested groups
within a pattern. See the C<as_string> method for more details.
When called without a parameter, no indenting is performed.

  $re->indent( 4 );
  print $re->as_string;

=cut

sub indent {
    my $self = shift;
    $self->{indent} = defined($_[0]) ? $_[0] : 0;
    return $self;
}

=item lookahead(0|1)

Turns on zero-width lookahead assertions. This is usually
beneficial when you expect that the pattern will usually fail.
If you expect that the pattern will usually match you will
probably be worse off.

=cut

sub lookahead {
    my $self = shift;
    $self->{lookahead} = defined($_[0]) ? $_[0] : 1;
    return $self;
}

=item flags(STRING)

Sets the flags that govern how the pattern behaves (for
versions of Perl up to 5.9 or so, these are C<imsx>). By
default no flags are enabled.


=item modifiers(STRING)

An alias of the C<flags> method, for users familiar with
C<Regexp::List>.

=cut

sub flags {
    my $self = shift;
    $self->{flags} = defined($_[0]) ? $_[0] : '';
    return $self;
}

sub modifiers {
    my $self = shift;
    return $self->flags(@_);
}

=item track(0|1)

Turns tracking on or off. When this attribute is enabled,
additional housekeeping information is inserted into the
assembled expression using C<({...}> embedded code
constructs. This provides the necessary information to
determine which, of the original patterns added, was the
one that caused the match.

  $re->track( 1 );
  if( $target =~ /$re/ ) {
    print "$target matched by ", $re->matched, "\n";
  }

Note that when this functionality is enabled, no
reduction is performed and no character classes are
generated. In other words, C<brag|tag> is not
reduced down to C<(?:br|t)ag> and C<dig|dim> is not
reduced to C<di[gm]>.

=cut

sub track {
    my $self = shift;
    $self->{track} = defined($_[0]) ? $_[0] : 1;
    return $self;
}

=item unroll_plus(0|1)

Turns the unrolling of plus metacharacters on or off. When
a pattern is broken up, C<a+> becomes C<a>, C<a*> (and
C<b+?> becomes C<b>, C<b*?>. This may allow the freed C<a>
to assemble with other patterns. Not enabled by default.

=cut

sub unroll_plus {
    my $self = shift;
    $self->{unroll_plus} = defined($_[0]) ? $_[0] : 1;
    return $self;
}

=item lex(SCALAR)

Change the pattern used to break a string apart into tokens.
You can examine the C<eg/naive> script as a starting point.

=cut

sub lex {
    my $self = shift;
    $self->{lex} = qr($_[0]);
    return $self;
}

=item reduce(0|1)

Turns pattern reduction on or off. A reduced pattern may
be considerably shorter than an unreduced pattern. Consider
C</sl(?:ip|op|ap)/> I<versus> C</sl[aio]p/>. An unreduced
pattern will be very similar to those produced by
C<Regexp::Optimizer>. Reduction is on by default. Turning
it off speeds assembly (but assembly is pretty fast -- it's
the breaking up of the initial patterns in the lexing stage
that can consume a non-negligible amount of time).

=cut

sub reduce {
    my $self = shift;
    $self->{reduce} = defined($_[0]) ? $_[0] : 1;
    return $self;
}

=item mutable(0|1)

This method has been marked as DEPRECATED. It will be removed
in a future release. See the C<clone> method for a technique
to replace its functionality.

=cut

sub mutable {
    my $self = shift;
    $self->{mutable} = defined($_[0]) ? $_[0] : 1;
    return $self;
}

=item reset

Empties out the patterns that have been C<add>ed or C<insert>-ed
into the object. Does not modify the state of controller attributes
such as C<debug>, C<lex>, C<reduce> and the like.

=cut

sub reset {
    # reinitialise the internal state of the object
    my $self = shift;
    $self->{path} = [];
    $self->{re}   = undef;
    $self->{str}  = undef;
    return $self;
}

=item Default_Lexer

B<Warning:> the C<Default_Lexer> function is a class method, not
an object method. It is a fatal error to call it as an object
method.

The C<Default_Lexer> method lets you replace the default pattern
used for all subsequently created C<Regexp::Assemble> objects. It
will not have any effect on existing objects. (It is also possible
to override the lexer pattern used on a per-object basis).

The parameter should be an ordinary scalar, not a compiled
pattern. If the pattern fails to match all parts of the string,
the missing parts will be returned as single chunks. Therefore
the following pattern is legal (albeit rather cork-brained):

    Regexp::Assemble::Default_Lexer( '\\d' );

The above pattern will split up input strings digit by digit, and
all non-digit characters as single chunks.

=cut

sub Default_Lexer {
    if( $_[0] ) {
        if( my $refname = ref($_[0]) ) {
            require Carp;
            Carp::croak("Cannot pass a $refname to Default_Lexer");
        }
        $Current_Lexer = $_[0];
    }
    return defined $Current_Lexer ? $Current_Lexer : $Default_Lexer;
}

# --- no user serviceable parts below ---

# -- debug helpers

sub _debug {
    my $self = shift;
    return $self->{debug} & shift() ? 1 : 0;
}

# -- helpers

sub _path {
    # access the path
    return $_[0]->{path};
}

# -- the heart of the matter

$have_Storable = do {
    eval {
        require Storable;
        import Storable 'dclone';
    };
    $@ ? 0 : 1;
};

sub _path_clone {
    $have_Storable ? dclone($_[0]) : _path_copy($_[0]);
}

sub _path_copy {
    my $path = shift;
    my $new  = [];
    for( my $p = 0; $p < @$path; ++$p ) {
        if( ref($path->[$p]) eq 'HASH' ) {
            push @$new, _node_copy($path->[$p]);
        }
        elsif( ref($path->[$p]) eq 'ARRAY' ) {
            push @$new, _path_copy($path->[$p]);
        }
        else {
            push @$new, $path->[$p];
        }
    }
    return $new;
}

sub _node_copy {
    my $node = shift;
    my $new  = {};
    while( my( $k, $v ) = each %$node ) {
        $new->{$k} = defined($v)
            ? _path_copy($v)
            : undef
        ;
    }
    return $new;
}

sub _insert_path {
    my $self  = shift;
    my $list  = shift;
    my $debug = shift;
    my @in    = @{shift()}; # create a new copy
    if( @$list == 0 ) { # special case the first time
        if( @in == 0 or (@in == 1 and (not defined $in[0] or $in[0] eq ''))) {
            return [{'' => undef}];
        }
        else {
            return \@in;
        }
    }
    $debug and print "# _insert_path @{[_dump(\@in)]} into @{[_dump($list)]}\n";
    my $path   = $list;
    my $offset = 0;
    my $token;
    if( not @in ) {
        if( ref($list->[0]) ne 'HASH' ) {
            return [ { '' => undef, $list->[0] => $list } ];
        }
        else {
            $list->[0]{''} = undef;
            return $list;
        }
    }
    while( defined( $token = shift @in )) {
        if( ref($token) eq 'HASH' ) {
            $debug and print "#  p0=", _dump($path), "\n";
            $path = $self->_insert_node( $path, $offset, $token, $debug, @in );
            $debug and print "#  p1=", _dump($path), "\n";
            last;
        }
        if( ref($path->[$offset]) eq 'HASH' ) {
            $debug and print "#   at (off=$offset len=@{[scalar @$path]}) ", _dump($path->[$offset]), "\n";
            my $node = $path->[$offset];
            if( exists( $node->{$token} )) {
                if ($offset < $#$path) {
                    my $new = {
                        $token => [$token, @in],
                        _re_path($self, [$node]) => [@{$path}[$offset..$#$path]],
                    };
                    splice @$path, $offset, @$path-$offset, $new;
                    last;
                }
                else {
                    $debug and print "#   descend key=$token @{[_dump($node->{$token})]}\n";
                    $path   = $node->{$token};
                    $offset = 0;
                    redo;
                }
            }
            else {
                $debug and print "#   add path ($token:@{[_dump(\@in)]}) into @{[_dump($path)]} at off=$offset to end=@{[scalar $#$path]}\n";
                if( $offset == $#$path ) {
                    $node->{$token} = [ $token, @in ];
                }
                else {
                    my $new = {
                        _node_key($token) => [ $token, @in ],
                        _node_key($node)  => [@{$path}[$offset..$#{$path}]],
                    };
                    splice( @$path, $offset, @$path - $offset, $new );
                    $debug and print "#   fused node=@{[_dump($new)]} path=@{[_dump($path)]}\n";
                }
                last;
            }
        }

        if( $debug ) {
            my $msg = '';
            my $n;
            for( $n = 0; $n < @$path; ++$n ) {
                $msg .= ' ' if $n;
                my $atom = ref($path->[$n]) eq 'HASH'
                    ? '{'.join( ' ', keys(%{$path->[$n]})).'}'
                    : $path->[$n]
                ;
                $msg .= $n == $offset ? "<$atom>" : $atom;
            }
            print "# at path ($msg)\n";
        }

        if( $offset >= @$path ) {
            push @$path, { $token => [ $token, @in ], '' => undef };
            $debug and print "#   added remaining @{[_dump($path)]}\n";
            last;
        }
        elsif( $token ne $path->[$offset] ) {
            $debug and print "#   token $token not present\n";
            splice @$path, $offset, @$path-$offset, {
                length $token
                    ? ( _node_key($token) => [$token, @in])
                    : ( '' => undef )
                ,
                $path->[$offset] => [@{$path}[$offset..$#{$path}]],
            };
            $debug and print "#   path=@{[_dump($path)]}\n";
            last;
        }
        elsif( not @in ) {
            $debug and print "#   last token to add\n";
            if( defined( $path->[$offset+1] )) {
                ++$offset;
                if( ref($path->[$offset]) eq 'HASH' ) {
                    $debug and print "#   add sentinel to node\n";
                    $path->[$offset]{''} = undef;
                }
                else {
                    $debug and print "#   convert <$path->[$offset]> to node for sentinel\n";
                    splice @$path, $offset, @$path-$offset, {
                        ''               => undef,
                        $path->[$offset] => [ @{$path}[$offset..$#{$path}] ],
                    };
                }
            }
            else {
                # already seen this pattern
                ++$self->{stats_dup};
            }
            last;
        }
        # if we get here then @_ still contains a token
        ++$offset;
    }
    $list;
}

sub _insert_node {
    my $self   = shift;
    my $path   = shift;
    my $offset = shift;
    my $token  = shift;
    my $debug  = shift;
    my $path_end = [@{$path}[$offset..$#{$path}]];
    # NB: $path->[$offset] and $[path_end->[0] are equivalent
    my $token_key = _re_path($self, [$token]);
    $debug and print "#  insert node(@{[_dump($token)]}:@{[_dump(\@_)]}) (key=$token_key)",
        " at path=@{[_dump($path_end)]}\n";
    if( ref($path_end->[0]) eq 'HASH' ) {
        if( exists($path_end->[0]{$token_key}) ) {
            if( @$path_end > 1 ) {
                my $path_key = _re_path($self, [$path_end->[0]]);
                my $new = {
                    $path_key  => [ @$path_end ],
                    $token_key => [ $token, @_ ],
                };
                $debug and print "#   +bifurcate new=@{[_dump($new)]}\n";
                splice( @$path, $offset, @$path_end, $new );
            }
            else {
                my $old_path = $path_end->[0]{$token_key};
                my $new_path = [];
                while( @$old_path and _node_eq( $old_path->[0], $token )) {
                    $debug and print "#  identical nodes in sub_path ",
                        ref($token) ? _dump($token) : $token, "\n";
                    push @$new_path, shift(@$old_path);
                    $token = shift @_;
                }
                if( @$new_path ) {
                    my $new;
                    my $token_key = $token;
                    if( @_ ) {
                        $new = {
                            _re_path($self, $old_path) => $old_path,
                            $token_key => [$token, @_],
                        };
                        $debug and print "#  insert_node(bifurc) n=@{[_dump([$new])]}\n";
                    }
                    else {
                        $debug and print "#  insert $token into old path @{[_dump($old_path)]}\n";
                        if( @$old_path ) {
                            $new = ($self->_insert_path( $old_path, $debug, [$token] ))->[0];
                        }
                        else {
                            $new = { '' => undef, $token => [$token] };
                        }
                    }
                    push @$new_path, $new;
                }
                $path_end->[0]{$token_key} = $new_path;
                $debug and print "#   +_insert_node result=@{[_dump($path_end)]}\n";
                splice( @$path, $offset, @$path_end, @$path_end );
            }
        }
        elsif( not _node_eq( $path_end->[0], $token )) {
            if( @$path_end > 1 ) {
                my $path_key = _re_path($self, [$path_end->[0]]);
                my $new = {
                    $path_key  => [ @$path_end ],
                    $token_key => [ $token, @_ ],
                };
                $debug and print "#   path->node1 at $path_key/$token_key @{[_dump($new)]}\n";
                splice( @$path, $offset, @$path_end, $new );
            }
            else {
                $debug and print "#   next in path is node, trivial insert at $token_key\n";
                $path_end->[0]{$token_key} = [$token, @_];
                splice( @$path, $offset, @$path_end, @$path_end );
            }
        }
        else {
            while( @$path_end and _node_eq( $path_end->[0], $token )) {
                $debug and print "#  identical nodes @{[_dump([$token])]}\n";
                shift @$path_end;
                $token = shift @_;
                ++$offset;
            }
            if( @$path_end ) {
                $debug and print "#   insert at $offset $token:@{[_dump(\@_)]} into @{[_dump($path_end)]}\n";
                $path_end = $self->_insert_path( $path_end, $debug, [$token, @_] );
                $debug and print "#   got off=$offset s=@{[scalar @_]} path_add=@{[_dump($path_end)]}\n";
                splice( @$path, $offset, @$path - $offset, @$path_end );
                $debug and print "#   got final=@{[_dump($path)]}\n";
            }
            else {
                $token_key = _node_key($token);
                my $new = {
                    ''         => undef,
                    $token_key => [ $token, @_ ],
                };
                $debug and print "#   convert opt @{[_dump($new)]}\n";
                push @$path, $new;
            }
        }
    }
    else {
        if( @$path_end ) {
            my $new = {
                $path_end->[0] => [ @$path_end ],
                $token_key     => [ $token, @_ ],
            };
            $debug and print "#   atom->node @{[_dump($new)]}\n";
            splice( @$path, $offset, @$path_end, $new );
            $debug and print "#   out=@{[_dump($path)]}\n";
        }
        else {
            $debug and print "#   add opt @{[_dump([$token,@_])]} via $token_key\n";
            push @$path, {
                ''         => undef,
                $token_key => [ $token, @_ ],
            };
        }
    }
    $path;
}

sub _reduce {
    my $self    = shift;
    my $context = { debug => $self->_debug(DEBUG_TAIL), depth => 0 };

    if ($self->_debug(DEBUG_TIME)) {
        $self->_init_time_func;
        my $now = $self->{_time_func}->();
        if (exists $self->{_begin_time}) {
            printf "# load=%0.6f\n", $now - $self->{_begin_time};
        }
        else {
            printf "# load-epoch=%0.6f\n", $now;
        }
        $self->{_begin_time} = $self->{_time_func}->();
    }

    my ($head, $tail) = _reduce_path( $self->_path, $context );
    $context->{debug} and print "# final head=", _dump($head), ' tail=', _dump($tail), "\n";
    if( !@$head ) {
        $self->{path} = $tail;
    }
    else {
        $self->{path} = [
            @{_unrev_path( $tail, $context )},
            @{_unrev_path( $head, $context )},
        ];
    }

    if ($self->_debug(DEBUG_TIME)) {
        my $now = $self->{_time_func}->();
        if (exists $self->{_begin_time}) {
            printf "# reduce=%0.6f\n", $now - $self->{_begin_time};
        }
        else {
            printf "# reduce-epoch=%0.6f\n", $now;
        }
        $self->{_begin_time} = $self->{_time_func}->();
    }

    $context->{debug} and print "# final path=", _dump($self->{path}), "\n";
    return $self;
}

sub _remove_optional {
    if( exists $_[0]->{''} ) {
        delete $_[0]->{''};
        return 1;
    }
    return 0;
}

sub _reduce_path {
    my ($path, $ctx) = @_;
    my $indent = ' ' x $ctx->{depth};
    my $debug  =       $ctx->{debug};
    $debug and print "#$indent _reduce_path $ctx->{depth} ", _dump($path), "\n";
    my $new;
    my $head = [];
    my $tail = [];
    while( defined( my $p = pop @$path )) {
        if( ref($p) eq 'HASH' ) {
            my ($node_head, $node_tail) = _reduce_node($p, _descend($ctx) );
            $debug and print "#$indent| head=", _dump($node_head), " tail=", _dump($node_tail), "\n";
            push @$head, @$node_head if scalar @$node_head;
            push @$tail, ref($node_tail) eq 'HASH' ? $node_tail : @$node_tail;
        }
        else {
            if( @$head ) {
                $debug and print "#$indent| push $p leaves @{[_dump($path)]}\n";
                push @$tail, $p;
            }
            else {
                $debug and print "#$indent| unshift $p\n";
                unshift @$tail, $p;
            }
        }
    }
    $debug and print "#$indent| tail nr=@{[scalar @$tail]} t0=", ref($tail->[0]),
        (ref($tail->[0]) eq 'HASH' ? " n=" . scalar(keys %{$tail->[0]}) : '' ),
        "\n";
    if( @$tail > 1
        and ref($tail->[0]) eq 'HASH'
        and keys %{$tail->[0]} == 2
    ) {
        my $opt;
        my $fixed;
        while( my ($key, $path) = each %{$tail->[0]} ) {
            $debug and print "#$indent| scan k=$key p=@{[_dump($path)]}\n";
            next unless $path;
            if (@$path == 1 and ref($path->[0]) eq 'HASH') {
                $opt = $path->[0];
            }
            else {
                $fixed = $path;
            }
        }
        if( exists $tail->[0]{''} ) {
            my $path = [@{$tail}[1..$#{$tail}]];
            $tail = $tail->[0];
            ($head, $tail, $path) = _slide_tail( $head, $tail, $path, _descend($ctx) );
            $tail = [$tail, @$path];
        }
    }
    $debug and print "#$indent _reduce_path $ctx->{depth} out head=", _dump($head), ' tail=', _dump($tail), "\n";
    return ($head, $tail);
}

sub _reduce_node {
    my ($node, $ctx) = @_;
    my $indent = ' ' x $ctx->{depth};
    my $debug  =       $ctx->{debug};
    my $optional = _remove_optional($node);
    $debug and print "#$indent _reduce_node $ctx->{depth} in @{[_dump($node)]} opt=$optional\n";
    if( $optional and scalar keys %$node == 1 ) {
        my $path = (values %$node)[0];
        if( not grep { ref($_) eq 'HASH' } @$path ) {
            # if we have removed an optional, and there is only one path
            # left then there is nothing left to compare. Because of the
            # optional it cannot participate in any further reductions.
            # (unless we test for equality among sub-trees).
            my $result = {
                ''         => undef,
                $path->[0] => $path
            };
            $debug and print "#$indent| fast fail @{[_dump($result)]}\n";
            return [], $result;
        }
    }

    my( $fail, $reduce ) = _scan_node( $node, _descend($ctx) );

    $debug and print "#$indent|_scan_node done opt=$optional reduce=@{[_dump($reduce)]} fail=@{[_dump($fail)]}\n";

    # We now perform tail reduction on each of the nodes in the reduce
    # hash. If we have only one key, we know we will have a successful
    # reduction (since everything that was inserted into the node based
    # on the value of the last token of each path all mapped to the same
    # value).

    if( @$fail == 0 and keys %$reduce == 1 and not $optional) {
        # every path shares a common path
        my $path = (values %$reduce)[0];
        my ($common, $tail) = _do_reduce( $path, _descend($ctx) );
        $debug and print "#$indent|_reduce_node  $ctx->{depth} common=@{[_dump($common)]} tail=", _dump($tail), "\n";
        return( $common, $tail );
    }

    # this node resulted in a list of paths, game over
    $ctx->{indent} = $indent;
    return _reduce_fail( $reduce, $fail, $optional, _descend($ctx) );
}

sub _reduce_fail {
    my( $reduce, $fail, $optional, $ctx ) = @_;
    my( $debug, $depth, $indent ) = @{$ctx}{qw(debug depth indent)};
    my %result;
    $result{''} = undef if $optional;
    my $p;
    for $p (keys %$reduce) {
        my $path = $reduce->{$p};
        if( scalar @$path == 1 ) {
            $path = $path->[0];
            $debug and print "#$indent| -simple opt=$optional unrev @{[_dump($path)]}\n";
            $path = _unrev_path($path, _descend($ctx) );
            $result{_node_key($path->[0])} = $path;
        }
        else {
            $debug and print "#$indent| _do_reduce(@{[_dump($path)]})\n";
            my ($common, $tail) = _do_reduce( $path, _descend($ctx) );
            $path = [
                (
                    ref($tail) eq 'HASH'
                        ? _unrev_node($tail, _descend($ctx) )
                        : _unrev_path($tail, _descend($ctx) )
                ),
                @{_unrev_path($common, _descend($ctx) )}
            ];
            $debug and print "#$indent| +reduced @{[_dump($path)]}\n";
            $result{_node_key($path->[0])} = $path;
        }
    }
    my $f;
    for $f( @$fail ) {
        $debug and print "#$indent| +fail @{[_dump($f)]}\n";
        $result{$f->[0]} = $f;
    }
    $debug and print "#$indent _reduce_fail $depth fail=@{[_dump(\%result)]}\n";
    return ( [], \%result );
}

sub _scan_node {
    my( $node, $ctx ) = @_;
    my $indent = ' ' x $ctx->{depth};
    my $debug  =       $ctx->{debug};

    # For all the paths in the node, reverse them. If the first token
    # of the path is a scalar, push it onto an array in a hash keyed by
    # the value of the scalar.
    #
    # If it is a node, call _reduce_node on this node beforehand. If we
    # get back a common head, all of the paths in the subnode shared a
    # common tail. We then store the common part and the remaining node
    # of paths (which is where the paths diverged from the end and install
    # this into the same hash. At this point both the common and the tail
    # are in reverse order, just as simple scalar paths are.
    #
    # On the other hand, if there were no common path returned then all
    # the paths of the sub-node diverge at the end character. In this
    # case the tail cannot participate in any further reductions and will
    # appear in forward order.
    #
    # certainly the hurgliest function in the whole file :(

    # $debug = 1 if $depth >= 8;
    my @fail;
    my %reduce;

    my $n;
    for $n(
        map { substr($_, index($_, '#')+1) }
        sort
        map {
            join( '|' =>
                scalar(grep {ref($_) eq 'HASH'} @{$node->{$_}}),
                _node_offset($node->{$_}),
                scalar @{$node->{$_}},
            )
            . "#$_"
        }
    keys %$node ) {
        my( $end, @path ) = reverse @{$node->{$n}};
        if( ref($end) ne 'HASH' ) {
            $debug and print "# $indent|_scan_node push reduce ($end:@{[_dump(\@path)]})\n";
            push @{$reduce{$end}}, [ $end, @path ];
        }
        else {
            $debug and print "# $indent|_scan_node head=", _dump(\@path), ' tail=', _dump($end), "\n";
            my $new_path;
            # deal with sing, singing => s(?:ing)?ing
            if( keys %$end == 2 and exists $end->{''} ) {
                my ($key, $opt_path) = each %$end;
                ($key, $opt_path) = each %$end if $key eq '';
                $opt_path = [reverse @{$opt_path}];
                $debug and print "# $indent| check=", _dump($opt_path), "\n";
                my $end = { '' => undef, $opt_path->[0] => [@$opt_path] };
                my $head = [];
                my $path = [@path];
                ($head, my $slide, $path) = _slide_tail( $head, $end, $path, $ctx );
                if( @$head ) {
                    $new_path = [ @$head, $slide, @$path ];
                }
            }
            if( $new_path ) {
                $debug and print "# $indent|_scan_node slid=", _dump($new_path), "\n";
                push @{$reduce{$new_path->[0]}}, $new_path;
            }
            else {
                my( $common, $tail ) = _reduce_node( $end, _descend($ctx) );
                    if( not @$common ) {
                    $debug and print "# $indent| +failed $n\n";
                    push @fail, [reverse(@path), $tail];
                }
                else {
                    my $path = [@path];
                    $debug and print "# $indent|_scan_node ++recovered common=@{[_dump($common)]} tail=",
                        _dump($tail), " path=@{[_dump($path)]}\n";
                    if( ref($tail) eq 'HASH'
                        and keys %$tail == 2
                    ) {
                        if( exists $tail->{''} ) {
                            ($common, $tail, $path) = _slide_tail( $common, $tail, $path, $ctx );
                        }
                    }
                    push @{$reduce{$common->[0]}}, [
                        @$common, 
                        (ref($tail) eq 'HASH' ? $tail : @$tail ),
                        @$path
                    ];
                }
            }
        }
    }
    $debug and print
        "# $indent|_scan_node counts: reduce=@{[scalar keys %reduce]} fail=@{[scalar @fail]}\n";
    return( \@fail, \%reduce );
}

sub _do_reduce {
    my ($path, $ctx) = @_;
    my $indent = ' ' x $ctx->{depth};
    my $debug  =       $ctx->{debug};
    my $ra = Regexp::Assemble->new(chomp=>0);
    $ra->debug($debug);
    $debug and print "# $indent| do @{[_dump($path)]}\n";
    $ra->_insertr( $_ ) for
        # When nodes come into the picture, we have to be careful
        # about how we insert the paths into the assembly.
        # Paths with nodes first, then closest node to front
        # then shortest path. Merely because if we can control
        # order in which paths containing nodes get inserted,
        # then we can make a couple of assumptions that simplify
        # the code in _insert_node.
        sort {
            scalar(grep {ref($_) eq 'HASH'} @$a)
            <=> scalar(grep {ref($_) eq 'HASH'} @$b)
                ||
            _node_offset($b) <=> _node_offset($a)
                ||
            scalar @$a <=> scalar @$b
        }
        @$path
    ;
    $path = $ra->_path;
    my $common = [];
    push @$common, shift @$path while( ref($path->[0]) ne 'HASH' );
    my $tail = scalar( @$path ) > 1 ? [@$path] : $path->[0];
    $debug and print "# $indent| _do_reduce common=@{[_dump($common)]} tail=@{[_dump($tail)]}\n";
    return ($common, $tail);
}

sub _node_offset {
    # return the offset that the first node is found, or -ve
    # optimised for speed
    my $nr = @{$_[0]};
    my $atom = -1;
    ref($_[0]->[$atom]) eq 'HASH' and return $atom while ++$atom < $nr;
    return -1;
}

sub _slide_tail {
    my $head   = shift;
    my $tail   = shift;
    my $path   = shift;
    my $ctx    = shift;
    my $indent = ' ' x $ctx->{depth};
    my $debug  =       $ctx->{debug};
    $debug and print "# $indent| slide in h=", _dump($head),
        ' t=', _dump($tail), ' p=', _dump($path), "\n";
    my $slide_path = (each %$tail)[-1];
    $slide_path = (each %$tail)[-1] unless defined $slide_path;
    $debug and print "# $indent| slide potential ", _dump($slide_path), " over ", _dump($path), "\n";
    while( defined $path->[0] and $path->[0] eq $slide_path->[0] ) {
        $debug and print "# $indent| slide=tail=$slide_path->[0]\n";
        my $slide = shift @$path;
        shift @$slide_path;
        push @$slide_path, $slide;
        push @$head, $slide;
    }
    $debug and print "# $indent| slide path ", _dump($slide_path), "\n";
    my $slide_node = {
        '' => undef,
        _node_key($slide_path->[0]) => $slide_path,
    };
    $debug and print "# $indent| slide out h=", _dump($head),
        ' s=', _dump($slide_node), ' p=', _dump($path), "\n";
    return ($head, $slide_node, $path);
}

sub _unrev_path {
    my ($path, $ctx) = @_;
    my $indent = ' ' x $ctx->{depth};
    my $debug  =       $ctx->{debug};
    my $new;
    if( not grep { ref($_) } @$path ) {
        $debug and print "# ${indent}_unrev path fast ", _dump($path);
        $new = [reverse @$path];
        $debug and print "#  -> ", _dump($new), "\n";
        return $new;
    }
    $debug and print "# ${indent}unrev path in ", _dump($path), "\n";
    while( defined( my $p = pop @$path )) {
        push @$new,
              ref($p) eq 'HASH'  ? _unrev_node($p, _descend($ctx) )
            : ref($p) eq 'ARRAY' ? _unrev_path($p, _descend($ctx) )
            : $p
        ;
    }
    $debug and print "# ${indent}unrev path out ", _dump($new), "\n";
    return $new;
}

sub _unrev_node {
    my ($node, $ctx ) = @_;
    my $indent = ' ' x $ctx->{depth};
    my $debug  =       $ctx->{debug};
    my $optional = _remove_optional($node);
    $debug and print "# ${indent}unrev node in ", _dump($node), " opt=$optional\n";
    my $new;
    $new->{''} = undef if $optional;
    my $n;
    for $n( keys %$node ) {
        my $path = _unrev_path($node->{$n}, _descend($ctx) );
        $new->{_node_key($path->[0])} = $path;
    }
    $debug and print "# ${indent}unrev node out ", _dump($new), "\n";
    return $new;
}

sub _node_key {
    my $node = shift;
    return _node_key($node->[0]) if ref($node) eq 'ARRAY';
    return $node unless ref($node) eq 'HASH';
    my $key = '';
    my $k;
    for $k( keys %$node ) {
        next if $k eq '';
        $key = $k if $key eq '' or $key gt $k;
    }
    return $key;
}

sub _descend {
    # Take a context object, and increase the depth by one.
    # By creating a fresh hash each time, we don't have to
    # bother adding make-work code to decrease the depth
    # when we return from what we called.
    my $ctx = shift;
    return {%$ctx, depth => $ctx->{depth}+1};
}

#####################################################################

sub _make_class {
    my $self = shift;
    my %set = map { ($_,1) } @_;
    delete $set{'\\d'} if exists $set{'\\w'};
    delete $set{'\\D'} if exists $set{'\\W'};
    return '.' if exists $set{'.'}
        or ($self->{fold_meta_pairs} and (
               (exists $set{'\\d'} and exists $set{'\\D'})
            or (exists $set{'\\s'} and exists $set{'\\S'})
            or (exists $set{'\\w'} and exists $set{'\\W'})
        ))
    ;
    for my $meta( q/\\d/, q/\\D/, q/\\s/, q/\\S/, q/\\w/, q/\\W/ ) {
        if( exists $set{$meta} ) {
            my $re = qr/$meta/;
            my @delete;
            $_ =~ /^$re$/ and push @delete, $_ for keys %set;
            delete @set{@delete} if @delete;
        }
    }
    return (keys %set)[0] if keys %set == 1;
    for my $meta( '.', '+', '*', '?', '(', ')', '^', '@', '$', '[', '/', ) {
        exists $set{"\\$meta"} and $set{$meta} = delete $set{"\\$meta"};
    }
    my $dash  = exists $set{'-'} ? do { delete($set{'-'}), '-' } : '';
    my $caret = exists $set{'^'} ? do { delete($set{'^'}), '^' } : '';
    my $class = join( '' => sort keys %set );
    $class =~ s/0123456789/\\d/ and $class eq '\\d' and return $class;
    return "[$dash$class$caret]";
}

sub _re_sort {
    return length $b <=> length $a || $a cmp $b
}

sub _combine {
    my $self = shift;
    my $type = shift;
    # print "c in = @{[_dump(\@_)]}\n";
    # my $combine = 
    return '('
    . $type
    . do {
        my( @short, @long );
        push @{ /^$Single_Char$/ ? \@short : \@long}, $_ for @_;
        if( @short == 1 ) {
            @long = sort _re_sort @long, @short;
        }
        elsif( @short > 1 ) {
            # yucky but true
            my @combine = (_make_class($self, @short), sort _re_sort @long);
            @long = @combine;
        }
        else {
            @long = sort _re_sort @long;
        }
        join( '|', @long );
    }
    . ')';
    # print "combine <$combine>\n";
    # $combine;
}

sub _combine_new {
    my $self = shift;
    my( @short, @long );
    push @{ /^$Single_Char$/ ? \@short : \@long}, $_ for @_;
    if( @short == 1 and @long == 0 ) {
        return $short[0];
    }
    elsif( @short > 1 and @short == @_ ) {
        return _make_class($self, @short);
    }
    else {
        return '(?:'
            . join( '|' =>
                @short > 1
                    ? ( _make_class($self, @short), sort _re_sort @long)
                    : ( (sort _re_sort( @long )), @short )
            )
        . ')';
    }
}

sub _re_path {
    my $self = shift;
    # in shorter assemblies, _re_path() is the second hottest
    # routine. after insert(), so make it fast.

    if ($self->{unroll_plus}) {
        # but we can't easily make this blockless
        my @arr = @{$_[0]};
        my $str = '';
        my $skip = 0;
        for my $i (0..$#arr) {
            if (ref($arr[$i]) eq 'ARRAY') {
                $str .= _re_path($self, $arr[$i]);
            }
            elsif (ref($arr[$i]) eq 'HASH') {
                $str .= exists $arr[$i]->{''}
                    ? _combine_new( $self,
                        map { _re_path( $self, $arr[$i]->{$_} ) } grep { $_ ne '' } keys %{$arr[$i]}
                    ) . '?'
                    : _combine_new($self, map { _re_path( $self, $arr[$i]->{$_} ) } keys %{$arr[$i]})
                ;
            }
            elsif ($i < $#arr and $arr[$i+1] =~ /\A$arr[$i]\*(\??)\Z/) {
                $str .= "$arr[$i]+" . (defined $1 ? $1 : '');
                ++$skip;
            }
            elsif ($skip) {
                $skip = 0;
            }
            else {
                $str .= $arr[$i];
            }
        }
        return $str;
    }

    return join( '', @_ ) unless grep { length ref $_ } @_;
    my $p;
    return join '', map {
        ref($_) eq '' ? $_
        : ref($_) eq 'HASH' ? do {
            # In the case of a node, see whether there's a '' which
            # indicates that the whole thing is optional and thus
            # requires a trailing ?
            # Unroll the two different paths to avoid the needless
            # grep when it isn't necessary.
            $p = $_;
            exists $_->{''}
            ?  _combine_new( $self,
                map { _re_path( $self, $p->{$_} ) } grep { $_ ne '' } keys %$_
            ) . '?'
            : _combine_new($self, map { _re_path( $self, $p->{$_} ) } keys %$_ )
        }
        : _re_path($self, $_) # ref($_) eq 'ARRAY'
    } @{$_[0]}
}

sub _lookahead {
    my $in = shift;
    my %head;
    my $path;
    for $path( keys %$in ) {
        next unless defined $in->{$path};
        # print "look $path: ", ref($in->{$path}[0]), ".\n";
        if( ref($in->{$path}[0]) eq 'HASH' ) {
            my $next = 0;
            while( ref($in->{$path}[$next]) eq 'HASH' and @{$in->{$path}} > $next + 1 ) {
                if( exists $in->{$path}[$next]{''} ) {
                    ++$head{$in->{$path}[$next+1]};
                }
                ++$next;
            }
            my $inner = _lookahead( $in->{$path}[0] );
            @head{ keys %$inner } = (values %$inner);
        }
        elsif( ref($in->{$path}[0]) eq 'ARRAY' ) {
            my $subpath = $in->{$path}[0]; 
            for( my $sp = 0; $sp < @$subpath; ++$sp ) {
                if( ref($subpath->[$sp]) eq 'HASH' ) {
                    my $follow = _lookahead( $subpath->[$sp] );
                    @head{ keys %$follow } = (values %$follow);
                    last unless exists $subpath->[$sp]{''};
                }
                else {
                    ++$head{$subpath->[$sp]};
                    last;
                }
            }
        }
        else {
            ++$head{ $in->{$path}[0] };
        }
    }
    # print "_lookahead ", _dump($in), '==>', _dump([keys %head]), "\n";
    return \%head;
}

sub _re_path_lookahead {
    my $self = shift;
    my $in  = shift;
    # print "_re_path_la in ", _dump($in), "\n";
    my $out = '';
    for( my $p = 0; $p < @$in; ++$p ) {
        if( ref($in->[$p]) eq '' ) {
            $out .= $in->[$p];
            next;
        }
        elsif( ref($in->[$p]) eq 'ARRAY' ) {
            $out .= _re_path_lookahead($self, $in->[$p]);
            next;
        }
        # print "$p ", _dump($in->[$p]), "\n";
        my $path = [
            map { _re_path_lookahead($self, $in->[$p]{$_} ) }
            grep { $_ ne '' }
            keys %{$in->[$p]}
        ];
        my $ahead = _lookahead($in->[$p]);
        my $more = 0;
        if( exists $in->[$p]{''} and $p + 1 < @$in ) {
            my $next = 1;
            while( $p + $next < @$in ) {
                if( ref( $in->[$p+$next] ) eq 'HASH' ) {
                    my $follow = _lookahead( $in->[$p+$next] );
                    @{$ahead}{ keys %$follow } = (values %$follow);
                }
                else {
                    ++$ahead->{$in->[$p+$next]};
                    last;
                }
                ++$next;
            }
            $more = 1;
        }
        my $nr_one = grep { /^$Single_Char$/ } @$path;
        my $nr     = @$path;
        if( $nr_one > 1 and $nr_one == $nr ) {
            $out .= _make_class($self, @$path);
            $out .= '?' if exists $in->[$p]{''};
        }
        else {
            my $zwla = keys(%$ahead) > 1
                ?  _combine($self, '?=', grep { s/\+$//; $_ } keys %$ahead )
                : '';
            my $patt = $nr > 1 ? _combine($self, '?:', @$path ) : $path->[0];
            # print "have nr=$nr n1=$nr_one n=", _dump($in->[$p]), ' a=', _dump([keys %$ahead]), " zwla=$zwla patt=$patt @{[_dump($path)]}\n";
            if( exists $in->[$p]{''} ) {
                $out .=  $more ? "$zwla(?:$patt)?" : "(?:$zwla$patt)?";
            }
            else {
                $out .= "$zwla$patt";
            }
        }
    }
    return $out;
}

sub _re_path_track {
    my $self      = shift;
    my $in        = shift;
    my $normal    = shift;
    my $augmented = shift;
    my $o;
    my $simple  = '';
    my $augment = '';
    for( my $n = 0; $n < @$in; ++$n ) {
        if( ref($in->[$n]) eq '' ) {
            $o = $in->[$n];
            $simple  .= $o;
            $augment .= $o;
            if( (
                    $n < @$in - 1
                    and ref($in->[$n+1]) eq 'HASH' and exists $in->[$n+1]{''}
                )
                or $n == @$in - 1
            ) {
                push @{$self->{mlist}}, $normal . $simple ;
                $augment .= $] < 5.009005
                    ? "(?{\$self->{m}=$self->{mcount}})"
                    : "(?{$self->{mcount}})"
                ;
                ++$self->{mcount};
            }
        }
        else {
            my $path = [
                map { $self->_re_path_track( $in->[$n]{$_}, $normal.$simple , $augmented.$augment ) }
                grep { $_ ne '' }
                keys %{$in->[$n]}
            ];
            $o = '(?:' . join( '|' => sort _re_sort @$path ) . ')';
            $o .= '?' if exists $in->[$n]{''};
            $simple  .= $o;
            $augment .= $o;
        }
    }
    return $augment;
}

sub _re_path_pretty {
    my $self = shift;
    my $in  = shift;
    my $arg = shift;
    my $pre    = ' ' x (($arg->{depth}+0) * $arg->{indent});
    my $indent = ' ' x (($arg->{depth}+1) * $arg->{indent});
    my $out = '';
    $arg->{depth}++;
    my $prev_was_paren = 0;
    for( my $p = 0; $p < @$in; ++$p ) {
        if( ref($in->[$p]) eq '' ) {
            $out .= "\n$pre" if $prev_was_paren;
            $out .= $in->[$p];
            $prev_was_paren = 0;
        }
        elsif( ref($in->[$p]) eq 'ARRAY' ) {
            $out .= _re_path($self, $in->[$p]);
        }
        else {
            my $path = [
                map { _re_path_pretty($self, $in->[$p]{$_}, $arg ) }
                grep { $_ ne '' }
                keys %{$in->[$p]}
            ];
            my $nr = @$path;
            my( @short, @long );
            push @{/^$Single_Char$/ ? \@short : \@long}, $_ for @$path;
            if( @short == $nr ) {
                $out .=  $nr == 1 ? $path->[0] : _make_class($self, @short);
                $out .= '?' if exists $in->[$p]{''};
            }
            else {
                $out .= "\n" if length $out;
                $out .= $pre if $p;
                $out .= "(?:\n$indent";
                if( @short < 2 ) {
                    my $r = 0;
                    $out .= join( "\n$indent|" => map {
                            $r++ and $_ =~ s/^\(\?:/\n$indent(?:/;
                            $_
                        }
                        sort _re_sort @$path
                    );
                }
                else {
                    $out .= join( "\n$indent|" => ( (sort _re_sort @long), _make_class($self, @short) ));
                }
                $out .= "\n$pre)";
                if( exists $in->[$p]{''} ) {
                    $out .= "\n$pre?";
                    $prev_was_paren = 0;
                }
                else {
                    $prev_was_paren = 1;
                }
            }
        }
    }
    $arg->{depth}--;
    return $out;
}

sub _node_eq {
    return 0 if not defined $_[0] or not defined $_[1];
    return 0 if ref $_[0] ne ref $_[1];
    # Now that we have determined that the reference of each
    # argument are the same, we only have to test the first
    # one, which gives us a nice micro-optimisation.
    if( ref($_[0]) eq 'HASH' ) {
        keys %{$_[0]} == keys %{$_[1]}
            and
        # does this short-circuit to avoid _re_path() cost more than it saves?
        join( '|' => sort keys %{$_[0]}) eq join( '|' => sort keys %{$_[1]})
            and
        _re_path(undef, [$_[0]] ) eq _re_path(undef, [$_[1]] );
    }
    elsif( ref($_[0]) eq 'ARRAY' ) {
        scalar @{$_[0]} == scalar @{$_[1]}
            and
        _re_path(undef, $_[0]) eq _re_path(undef, $_[1]);
    }
    else {
        $_[0] eq $_[1];
    }
}

sub _pretty_dump {
    return sprintf "\\x%02x", ord(shift);
}

sub _dump {
    my $path = shift;
    return _dump_node($path) if ref($path) eq 'HASH';
    my $dump = '[';
    my $d;
    my $nr = 0;
    for $d( @$path ) {
        $dump .= ' ' if $nr++;
        if( ref($d) eq 'HASH' ) {
            $dump .= _dump_node($d);
        }
        elsif( ref($d) eq 'ARRAY' ) {
            $dump .= _dump($d);
        }
        elsif( defined $d ) {
            # D::C indicates the second test is redundant
            # $dump .= ( $d =~ /\s/ or not length $d )
            $dump .= (
                $d =~ /\s/            ? qq{'$d'}         :
                $d =~ /^[\x00-\x1f]$/ ? _pretty_dump($d) :
                $d
            );
        }
        else {
            $dump .= '*';
        }
    }
    return $dump . ']';
}

sub _dump_node {
    my $node = shift;
    my $dump = '{';
    my $nr   = 0;
    my $n;
    for $n (sort keys %$node) {
        $dump .= ' ' if $nr++;
        # Devel::Cover shows this to test to be redundant
        # $dump .= ( $n eq '' and not defined $node->{$n} )
        $dump .= $n eq ''
            ? '*'
            : ($n =~ /^[\x00-\x1f]$/ ? _pretty_dump($n) : $n)
                . "=>" . _dump($node->{$n})
        ;
    }
    return $dump . '}';
}

=back

=head1 DIAGNOSTICS

  "Cannot pass a C<refname> to Default_Lexer"

You tried to replace the default lexer pattern with an object
instead of a scalar. Solution: You probably tried to call
C<< $obj->Default_Lexer >>. Call the qualified class method instead
C<Regexp::Assemble::Default_Lexer>.

  "filter method not passed a coderef"

  "pre_filter method not passed a coderef"

A reference to a subroutine (anonymous or otherwise) was expected.
Solution: read the documentation for the C<filter> method.

  "duplicate pattern added: /.../"

The C<dup_warn> attribute is active, and a duplicate pattern was
added (well duh!). Solution: clean your data.

  "cannot open [file] for input: [reason]"

The C<add_file> method was unable to open the specified file for
whatever reason. Solution: make sure the file exists and the script
has the required privileges to read it.

=head1 NOTES

This module has been tested successfully with a range of versions
of perl, from 5.005_03 to 5.9.3. Use of 5.6.0 is not recommended.

The expressions produced by this module can be used with the PCRE
library.

Remember to "double up" your backslashes if the patterns are
hard-coded as constants in your program. That is, you should
literally C<add('a\\d+b')> rather than C<add('a\d+b')>. It
usually will work either way, but it's good practice to do so.

Where possible, supply the simplest tokens possible. Don't add
C<X(?-\d+){2})Y> when C<X-\d+-\d+Y> will do. The reason is that
if you also add C<X\d+Z> the resulting assembly changes
dramatically: C<X(?:(?:-\d+){2}Y|-\d+Z)> I<versus>
C<X-\d+(?:-\d+Y|Z)>. Since R::A doesn't perform enough analysis,
it won't "unroll" the C<{2}> quantifier, and will fail to notice
the divergence after the first C<-d\d+>.

Furthermore, when the string 'X-123000P' is matched against the
first assembly, the regexp engine will have to backtrack over each
alternation (the one that ends in Y B<and> the one that ends in Z)
before determining that there is no match. No such backtracking
occurs in the second pattern: as soon as the engine encounters the
'P' in the target string, neither of the alternations at that point
(C<-\d+Y> or C<Z>) could succeed and so the match fails.

C<Regexp::Assemble> does, however, know how to build character
classes. Given C<a-b>, C<axb> and C<a\db>, it will assemble these
into C<a[-\dx]b>. When C<-> (dash) appears as a candidate for a
character class it will be the first character in the class. When
C<^> (circumflex) appears as a candidate for a character class it
will be the last character in the class.

It also knows about meta-characters than can "absorb" regular
characters. For instance, given C<X\d> and C<X5>, it knows that
C<5> can be represented by C<\d> and so the assembly is just C<X\d>.
The "absorbent" meta-characters it deals with are C<.>, C<\d>, C<\s>
and C<\W> and their complements. It will replace C<\d>/C<\D>,
C<\s>/C<\S> and C<\w>/C<\W> by C<.> (dot), and it will drop C<\d>
if C<\w> is also present (as will C<\D> in the presence of C<\W>).

C<Regexp::Assemble> deals correctly with C<quotemeta>'s propensity
to backslash many characters that have no need to be. Backslashes on
non-metacharacters will be removed. Similarly, in character classes,
a number of characters lose their magic and so no longer need to be
backslashed within a character class. Two common examples are C<.>
(dot) and C<$>. Such characters will lose their backslash.

At the same time, it will also process C<\Q...\E> sequences. When
such a sequence is encountered, the inner section is extracted and
C<quotemeta> is applied to the section. The resulting quoted text
is then used in place of the original unquoted text, and the C<\Q>
and C<\E> metacharacters are thrown away. Similar processing occurs
with the C<\U...\E> and C<\L...\E> sequences. This may have surprising
effects when using a dispatch table. In this case, you will need
to know exactly what the module makes of your input. Use the C<lexstr>
method to find out what's going on:

  $pattern = join( '', @{$re->lexstr($pattern)} );

If all the digits 0..9 appear in a character class, C<Regexp::Assemble>
will replace them by C<\d>. I'd do it for letters as well, but
thinking about accented characters and other glyphs hurts my head.

In an alternation, the longest paths are chosen first (for example,
C<horse|bird|dog>). When two paths have the same length, the path
with the most subpaths will appear first. This aims to put the
"busiest" paths to the front of the alternation. For example, the
list C<bad>, C<bit>, C<few>, C<fig> and C<fun> will produce the
pattern C<(?:f(?:ew|ig|un)|b(?:ad|it))>. See F<eg/tld> for a
real-world example of how alternations are sorted. Once you have
looked at that, everything should be crystal clear.

When tracking is in use, no reduction is performed. nor are 
character classes formed. The reason is that it is
too difficult to determine the original pattern afterwards. Consider the
two patterns C<pale> and C<palm>. These should be reduced to
C<pal[em]>. The final character matches one of two possibilities.
To resolve whether it matched an C<'e'> or C<'m'> would require
keeping track of the fact that the pattern finished up in a character
class, which would the require a whole lot more work to figure out
which character of the class matched. Without character classes
it becomes much easier. Instead, C<pal(?:e|m)> is produced, which
lets us find out more simply where we ended up.

Similarly, C<dogfood> and C<seafood> should form C<(?:dog|sea)food>.
When the pattern is being assembled, the tracking decision needs
to be made at the end of the grouping, but the tail of the pattern
has not yet been visited. Deferring things to make this work correctly
is a vast hassle. In this case, the pattern becomes merely
C<(?:dogfood|seafood>. Tracked patterns will therefore be bulkier than
simple patterns.

There is an open bug on this issue:

L<http://rt.perl.org/rt3/Ticket/Display.html?id=32840>

If this bug is ever resolved, tracking would become much easier to
deal with (none of the C<match> hassle would be required - you could
just match like a regular RE and it would Just Work).

=head1 SEE ALSO

=over 8

=item L<perlre>

General information about Perl's regular expressions.

=item L<re>

Specific information about C<use re 'eval'>.

=item Regex::PreSuf

C<Regex::PreSuf> takes a string and chops it itself into tokens of
length 1. Since it can't deal with tokens of more than one character,
it can't deal with meta-characters and thus no regular expressions.
Which is the main reason why I wrote this module.

=item Regexp::Optimizer

C<Regexp::Optimizer> produces regular expressions that are similar to
those produced by R::A with reductions switched off. It's biggest
drawback is that it is exponentially slower than Regexp::Assemble on
very large sets of patterns.

=item Regexp::Parser

Fine grained analysis of regular expressions.

=item Regexp::Trie

Funnily enough, this was my working name for C<Regexp::Assemble>
during its developement. I changed the name because I thought it
was too obscure. Anyway, C<Regexp::Trie> does much the same as
C<Regexp::Optimizer> and C<Regexp::Assemble> except that it runs
much faster (according to the author). It does not recognise
meta characters (that is, 'a+b' is interpreted as 'a\+b').

=item Text::Trie

C<Text::Trie> is well worth investigating. Tries can outperform very
bushy (read: many alternations) patterns.

=item Tree::Trie

C<Tree::Trie> is another module that builds tries. The algorithm that
C<Regexp::Assemble> uses appears to be quite similar to the
algorithm described therein, except that C<R::A> solves its
end-marker problem without having to rewrite the leaves.

=back

=head1 LIMITATIONS

C<Regexp::Assemble> does not attempt to find common substrings. For
instance, it will not collapse C</cabababc/> down to C</c(?:ab){3}c/>.
If there's a module out there that performs this sort of string
analysis I'd like to know about it. But keep in mind that the
algorithms that do this are very expensive: quadratic or worse.

C<Regexp::Assemble> does not interpret meta-character modifiers.
For instance, if the following two patterns are
given: C<X\d> and C<X\d+>, it will not determine that C<\d> can be
matched by C<\d+>. Instead, it will produce C<X(?:\d|\d+)>. Along
a similar line of reasoning, it will not determine that C<Z> and
C<Z\d+> is equivalent to C<Z\d*> (It will produce C<Z(?:\d+)?>
instead).

You cannot remove a pattern that has been added to an object. You'll
just have to start over again. Adding a pattern is difficult enough,
I'd need a solid argument to convince me to add a C<remove> method.
If you need to do this you should read the documentation for the
C<clone> method.

C<Regexp::Assemble> does not (yet)? employ the C<(?E<gt>...)>
construct.

The module does not produce POSIX-style regular expressions. This
would be quite easy to add, if there was a demand for it.

=head1 BUGS

Patterns that generate look-ahead assertions sometimes produce
incorrect patterns in certain obscure corner cases. If you
suspect that this is occurring in your pattern, disable
lookaheads.

Tracking doesn't really work at all with 5.6.0. It works better
in subsequent 5.6 releases. For maximum reliability, the use of
a 5.8 release is strongly recommended. Tracking barely works with
5.005_04. Of note, using C<\d>-style meta-characters invariably
causes panics. Tracking really comes into its own in Perl 5.10.

If you feed C<Regexp::Assemble> patterns with nested parentheses,
there is a chance that the resulting pattern will be uncompilable
due to mismatched parentheses (not enough closing parentheses). This
is normal, so long as the default lexer pattern is used. If you want
to find out which pattern among a list of 3000 patterns are to blame
(speaking from experience here), the F<eg/debugging> script offers
a strategy for pinpointing the pattern at fault. While you may not
be able to use the script directly, the general approach is easy to
implement.

The algorithm used to assemble the regular expressions makes extensive
use of mutually-recursive functions (that is, A calls B, B calls
A, ...) For deeply similar expressions, it may be possible to provoke
"Deep recursion" warnings.

The module has been tested extensively, and has an extensive test
suite (that achieves close to 100% statement coverage), but you
never know...  A bug may manifest itself in two ways: creating a
pattern that cannot be compiled, such as C<a\(bc)>, or a pattern
that compiles correctly but that either matches things it shouldn't,
or doesn't match things it should. It is assumed that Such problems
will occur when the reduction algorithm encounters some sort of
edge case. A temporary work-around is to disable reductions:

  my $pattern = $assembler->reduce(0)->re;

A discussion about implementation details and where bugs might lurk
appears in the README file. If this file is not available locally,
you should be able to find a copy on the Web at your nearest CPAN
mirror.

Seriously, though, a number of people have been using this module to
create expressions anywhere from 140Kb to 600Kb in size, and it seems to
be working according to spec. Thus, I don't think there are any serious
bugs remaining.

If you are feeling brave, extensive debugging traces are available to
figure out where assembly goes wrong.

Please report all bugs at
L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Regexp-Assemble>

Make sure you include the output from the following two commands:

  perl -MRegexp::Assemble -le 'print $Regexp::Assemble::VERSION'
  perl -V

There is a mailing list for the discussion of C<Regexp::Assemble>.
Subscription details are available at
L<http://listes.mongueurs.net/mailman/listinfo/regexp-assemble>.

=head1 ACKNOWLEDGEMENTS

This module grew out of work I did building access maps for Postfix,
a modern SMTP mail transfer agent. See L<http://www.postfix.org/>
for more information. I used Perl to build large regular expressions
for blocking dynamic/residential IP addresses to cut down on spam
and viruses. Once I had the code running for this, it was easy to
start adding stuff to block really blatant spam subject lines, bogus
HELO strings, spammer mailer-ids and more...

I presented the work at the French Perl Workshop in 2004, and the
thing most people asked was whether the underlying mechanism for
assembling the REs was available as a module. At that time it was
nothing more that a twisty maze of scripts, all different. The
interest shown indicated that a module was called for. I'd like to
thank the people who showed interest. Hey, it's going to make I<my>
messy scripts smaller, in any case.

Thomas Drugeon was a valuable sounding board for trying out
early ideas. Jean Forget and Philippe Blayo looked over an early
version. H.Merijn Brandt stopped over in Paris one evening, and
discussed things over a few beers.

Nicholas Clark pointed out that while what this module does
(?:c|sh)ould be done in perl's core, as per the 2004 TODO, he
encouraged me to continue with the development of this module. In
any event, this module allows one to gauge the difficulty of
undertaking the endeavour in C. I'd rather gouge my eyes out with
a blunt pencil.

Paul Johnson settled the question as to whether this module should
live in the Regex:: namespace, or Regexp:: namespace. If you're
not convinced, try running the following one-liner:

  perl -le 'print ref qr//'

Philippe Bruhat found a couple of corner cases where this module
could produce incorrect results. Such feedback is invaluable,
and only improves the module's quality.

=head1 AUTHOR

David Landgren

Copyright (C) 2004-2008. All rights reserved.

  http://www.landgren.net/perl/

If you use this module, I'd love to hear about what you're using
it for. If you want to be informed of updates, send me a note.

You can look at the latest working copy in the following
Subversion repository:

  http://svnweb.mongueurs.net/Regexp-Assemble

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

'The Lusty Decadent Delights of Imperial Pompeii';
__END__
