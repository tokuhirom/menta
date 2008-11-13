# based on Mojo::Template. Copyright (C) 2010, Sebastian Riedel.
# some modified by tokuhirom

package MENTA::Template;
use strict;
use warnings;
use constant DEBUG => $ENV{MENTA_TEMPLATE_DEBUG} || 0;

use Carp 'croak';

sub new {
    my $class = shift;
    return bless {
        code => '',
        comment_mark => '#',
        expression_mark => '=',
        raw_expression_mark => '=r',
        line_start => '%',
        template => '',
        tree => [],
        tag_start => '<%',
        tag_end => '%>',
    }, $class;
}

sub code { shift->{code} }

sub build {
    my $self = shift;

    # Compile
    my @lines;
    for my $line (@{$self->{tree}}) {

        # New line
        push @lines, '';
        for (my $j = 0; $j < @{$line}; $j += 2) {
            my $type  = $line->[$j];
            my $value = $line->[$j + 1];

            # Need to fix line ending?
            my $newline = chomp $value;

            # Text
            if ($type eq 'text') {

                # Quote and fix line ending
                $value = quotemeta($value);
                $value .= '\n' if $newline;

                $lines[-1] .= "\$_MENTA .= \"" . $value . "\";";
            }

            # Code
            if ($type eq 'code') {
                $lines[-1] .= "$value;";
            }

            # Expression
            if ($type eq 'expr') {
                $lines[-1] .= "\$_MENTA .= escape_html(scalar $value);";
            }

            # Raw Expression
            if ($type eq 'raw_expr') {
                $lines[-1] .= "\$_MENTA .= $value;";
            }
        }
    }

    # Wrap
    $lines[0] ||= '';
    $lines[0]   = q/sub { my $_MENTA = '';/ . $lines[0];
    $lines[-1] .= q/return $_MENTA; }/;

    $self->{code} = join "\n", @lines;
    return $self;
}

# I am so smart! I am so smart! S-M-R-T! I mean S-M-A-R-T...
sub parse {
    my ($self, $tmpl) = @_;
    $self->{template} = $tmpl;

    # Clean start
    delete $self->{tree};

    # Tags
    my $line_start    = quotemeta $self->{line_start};
    my $tag_start     = quotemeta $self->{tag_start};
    my $tag_end       = quotemeta $self->{tag_end};
    my $cmnt_mark     = quotemeta $self->{comment_mark};
    my $expr_mark     = quotemeta $self->{expression_mark};
    my $raw_expr_mark = quotemeta $self->{raw_expression_mark};

    # Tokenize
    my $state = 'text';
    my $multiline_expression = 0;
    for my $line (split /\n/, $tmpl) {

        # Perl line without return value
        if ($line =~ /^$line_start\s+(.+)$/) {
            push @{$self->{tree}}, ['code', $1];
            $multiline_expression = 0;
            next;
        }

        # Perl line with return value
        if ($line =~ /^$line_start$expr_mark\s+(.+)$/) {
            push @{$self->{tree}}, ['expr', $1];
            $multiline_expression = 0;
            next;
        }

        # Perl line with raw return value
        if ($line =~ /^$line_start$raw_expr_mark\s+(.+)$/) {
            push @{$self->{tree}}, ['raw_expr', $1];
            $multiline_expression = 0;
            next;
        }

        # Comment line, dummy token needed for line count
        if ($line =~ /^$line_start$cmnt_mark\s+(.+)$/) {
            push @{$self->{tree}}, [];
            $multiline_expression = 0;
            next;
        }

        # Escaped line ending?
        if ($line =~ /(\\+)$/) {
            my $length = length $1;

            # Newline escaped
            if ($length == 1) {
                $line =~ s/\\$//;
            }

            # Backslash escaped
            if ($length >= 2) {
                $line =~ s/\\\\$/\\/;
                $line .= "\n";
            }
        }

        # Normal line ending
        else { $line .= "\n" }

        # Mixed line
        my @token;
        for my $token (split /
            (
                $tag_start$raw_expr_mark # Raw Expression
            |
                $tag_start$expr_mark     # Expression
            |
                $tag_start$cmnt_mark     # Comment
            |
                $tag_start               # Code
            |
                $tag_end                 # End
            )
        /x, $line) {

            # Garbage
            next unless $token;

            # End
            if ($token =~ /^$tag_end$/) {
                $state = 'text';
                $multiline_expression = 0;
            }

            # Code
            elsif ($token =~ /^$tag_start$/) { $state = 'code' }

            # Comment
            elsif ($token =~ /^$tag_start$cmnt_mark$/) { $state = 'cmnt' }

            # Raw Expression
            elsif ($token =~ /^$tag_start$raw_expr_mark$/) {
                $state = 'raw_expr';
            }

            # Expression
            elsif ($token =~ /^$tag_start$expr_mark$/) {
                $state = 'expr';
            }

            # Value
            else {

                # Comments are ignored
                next if $state eq 'cmnt';

                # Multiline expressions are a bit complicated,
                # only the first line can be compiled as 'expr'
                $state = 'code' if $multiline_expression;
                $multiline_expression = 1 if $state eq 'expr';

                # Store value
                push @token, $state, $token;
            }
        }
        push @{$self->{tree}}, \@token;
    }

    return $self;
}

sub _context {
    my ($self, $text, $line) = @_;

    $line     -= 1;
    my $nline  = $line + 1;
    my $pline  = $line - 1;
    my $nnline = $line + 2;
    my $ppline = $line - 2;
    my @lines  = split /\n/, $text;

    # Context
    my $context = (($line + 1) . ': ' . $lines[$line] . "\n");

    # -1
    $context = (($pline + 1) . ': ' . $lines[$pline] . "\n" . $context)
      if $lines[$pline];

    # -2
    $context = (($ppline + 1) . ': ' . $lines[$ppline] . "\n" . $context)
      if $lines[$ppline];

    # +1
    $context = ($context . ($nline + 1) . ': ' . $lines[$nline] . "\n")
      if $lines[$nline];

    # +2
    $context = ($context . ($nnline + 1) . ': ' . $lines[$nnline] . "\n")
      if $lines[$nnline];

    return $context;
}

# Debug goodness
sub _error {
    my ($self, $error) = @_;

    # No trace in production mode
    return undef unless DEBUG;

    # Line
    if ($error =~ /at\s+\(eval\s+\d+\)\s+line\s+(\d+)/) {
        my $line  = $1;
        my $delim = '-' x 76;

        my $report = "\nTemplate error around line $line.\n";
        my $template = $self->_context($self->{template}, $line);
        $report .= "$delim\n$template$delim\n";

        # Advanced debugging
        if (DEBUG >= 2) {
            my $code = $self->_context($self->code, $line);
            $report .= "$code$delim\n";
        }

        $report .= "$error\n";
        return $report;
    }

    # No line found
    return "Template error: $error";
}

1;
