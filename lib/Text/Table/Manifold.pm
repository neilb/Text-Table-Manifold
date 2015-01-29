package Text::Table::Manifold;

use strict;
use warnings;
use warnings qw(FATAL utf8); # Fatalize encoding glitches.
use open     qw(:std :utf8); # Undeclared streams in UTF-8.

use Const::Exporter constants =>
[
	# Values of alignment().

	justify_left   => 0,
	justify_center => 1,
	justify_right  => 2,

	# Values for empty(), i.e. empty string handling.

	empty_as_empty => 0, # Do nothing.
	empty_as_minus => 1,
	empty_as_text  => 2, # 'empty'.
	empty_as_undef => 3,

	# Values for style().

	as_boxed       => 0, # The default.
	as_github      => 1,
	as_html        => 2,

	# Values for undef(), i.e. undef handling.

	undef_as_empty => 0,
	undef_as_minus => 1,
	undef_as_text  => 2, # 'undef'.
	undef_as_undef => 3, # Do nothing.
];

use List::AllUtils 'max';

use Moo;

use Types::Standard qw/Any ArrayRef HashRef Int Str/;

use Unicode::GCString;

has alignment =>
(
	default  => sub{return justify_center},
	is       => 'rw',
	isa      => Int,
	required => 0,
);

has data =>
(
	default  => sub{return []},
	is       => 'rw',
	isa      => ArrayRef,
	required => 0,
);

has empty =>
(
	default  => sub{return empty_as_empty},
	is       => 'rw',
	isa      => Int,
	required => 0,
);

has escapes =>
(
	default  => sub{return []},
	is       => 'rw',
	isa      => ArrayRef,
	required => 0,
);

has footers =>
(
	default  => sub{return []},
	is       => 'rw',
	isa      => ArrayRef,
	required => 0,
);

has headers =>
(
	default  => sub{return []},
	is       => 'rw',
	isa      => ArrayRef,
	required => 0,
);

has padding =>
(
	default  => sub{return 0},
	is       => 'rw',
	isa      => Int,
	required => 0,
);

has pass_thru =>
(
	default  => sub{return {} },
	is       => 'rw',
	isa      => HashRef,
	required => 0,
);

has style =>
(
	default  => sub{return as_boxed},
	is       => 'rw',
	isa      => Int,
	required => 0,
);

has undef =>
(
	default  => sub{return undef_as_undef},
	is       => 'rw',
	isa      => Int,
	required => 0,
);

has widths =>
(
	default  => sub{return []},
	is       => 'rw',
	isa      => ArrayRef,
	required => 0,
);

our $VERSION = '0.90';

# ------------------------------------------------

sub align_center
{
	my($self, $s, $width, $padding) = @_;
	$s           ||= '';
	my($s_width) = Unicode::GCString -> new($s) -> chars;
	my($left)    = int( ($width - $s_width) / 2);
	my($right)   = $width - $s_width - $left;

	return (' ' x ($left + $padding) ) . $s . (' ' x ($right + $padding) );

} # End of align_center;

# ------------------------------------------------

sub align_left
{
	my($self, $s, $width, $padding) = @_;
	$s           ||= '';
	my($s_width) = Unicode::GCString -> new($s || '') -> chars;
	my($left)    = $width - $s_width;

	return (' ' x ($left + $padding) ) . $s . ' ';

} # End of align_left;

# ------------------------------------------------

sub align_right
{
	my($self, $s, $width, $padding) = @_;
	$s           ||= '';
	my($s_width) = Unicode::GCString -> new($s || '') -> chars;
	my($right)   = $width - $s_width;

	return ' ' . $s . (' ' x ($right + $padding) );

} # End of align_right;

# ------------------------------------------------

sub _clean_data
{
	my($self, $headers, $data, $footers) = @_;

	for my $column (0 .. $#$headers)
	{
		$$headers[$column] = defined($$headers[$column]) ? $$headers[$column] : '-';
	}

	for my $column (0 .. $#$footers)
	{
		$$footers[$column] = defined($$footers[$column]) ? $$footers[$column] : '-';
	}

	my($empty) = $self -> empty;
	my($undef) = $self -> undef;

	my($s);

	for my $row (0 .. $#$data)
	{
		for my $column (0 .. $#{$$data[$row]})
		{
			$s = $$data[$row][$column];
			$s = defined($s)
					? (length($s) == 0) # Unicode::GCString should not be necessary here.
						? ($empty & empty_as_minus)
							? '-'
							: ($empty & empty_as_text)
								? 'empty'
								: ($empty & empty_as_undef)
									? undef
									: $s # No need to check to empty_as_empty here!
						: $s
					: ($undef & undef_as_empty)
							? ''
							: ($undef & undef_as_minus)
								? '-'
								: ($undef & undef_as_text)
									? 'undef'
									: $s; # No need to check for undef_as_undef here!

			$$data[$row][$column] = $s;
		}
	}

} # End of _clean_data.

# ------------------------------------------------

sub gather_statistics
{
	my($self, $headers, $data, $footers) = @_;

	$self -> _clean_data($headers, $data, $footers);

	my($column_count);

	for my $row (0 .. $#$data)
	{
		$column_count = $#{$$data[$row]};

		die "Error: # of data columns (@{[$column_count]}) in row @{[$row + 1]} != # of header columns (@{[$#$headers]})\n" if ($column_count != $#$headers);
	}

	my(@column);
	my($header_width);
	my(@max_widths);

	for my $column (0 .. $#$headers)
	{
		@column = ($$headers[$column], $$footers[$column]);

		for my $row (0 .. $#$data)
		{
			push @column, $$data[$row][$column];
		}

		push @max_widths, max map{Unicode::GCString -> new($_ || '') -> chars} @column;
	}

	$self -> widths(\@max_widths);

} # End of gather_statistics.

# ------------------------------------------------

sub render
{
	my($self, %hash) = @_;

	for my $key (keys %hash)
	{
		$self -> $key($hash{$key});
	}

	my($output);

	if ($self -> style == as_boxed)
	{
		$output = $self -> render_as_boxed;
	}
	elsif ($self -> style == as_github)
	{
		$output = $self -> render_as_github;
	}
	elsif ($self -> style == as_html)
	{
		$output = $self -> render_as_html;
	}
	else
	{
		die 'Error: Style not implemented: ' . $self -> style . "\n";
	}

	return $output;

} # End of render.

# ------------------------------------------------

sub render_as_boxed
{
	my($self)    = @_;
	my($headers) = $self -> headers;
	my($data)    = $self -> data;
	my($footers) = $self -> footers;

	$self -> gather_statistics($headers, $data, $footers);

	my($padding)   = $self -> padding;
	my($widths)    = $self -> widths;
	my($separator) = '+' . join('+', map{'-' x ($_ + 2 * $padding)} @$widths) . '+';
	my(@output)    = $separator;

	my(@s);

	for my $column (0 .. $#$widths)
	{
		push @s, $self -> align_center($$headers[$column], $$widths[$column], $padding);
	}

	push @output, '|' . join('|', @s) . '|';
	push @output, $separator;

	for my $row (0 .. $#$data)
	{
		@s = ();

		for my $column (0 .. $#$widths)
		{
			push @s, $self -> align_center($$data[$row][$column], $$widths[$column], $padding);
		}

		push @output, '|' . join('|', @s) . '|';
	}

	push @output, $separator;

	return [@output];

} # End of render_as_boxed.

# ------------------------------------------------

sub render_as_github
{
	my($self)    = @_;
	my($headers) = $self -> headers;
	my($data)    = $self -> data;
	my($footers) = $self -> footers;

	$self -> gather_statistics($headers, $data, $footers);

	my(@output) = (join('|', @$headers), join('|', map{'-' x $_} @{$self -> widths}) );

	for my $row (0 .. $#$data)
	{
		push @output, join('|', map{defined($_) ? $_ : ''} @{$$data[$row]});
	}

	return [@output];

} # End of render_as_github.

# ------------------------------------------------

sub render_as_html
{
	my($self)    = @_;
	my($headers) = $self -> headers;
	my($data)    = $self -> data;
	my($footers) = $self -> footers;

	$self -> gather_statistics($headers, $data, $footers);

	# What if there are no headers!

	my($table)         = '';
	my($table_options) = ${$self -> pass_thru}{table} || {};
	my(@table_keys)    = sort keys %$table_options;

	if (scalar @table_keys)
	{
		$table .= ' ' . join(' ', map{qq|$_ = "$$table_options{$_}"|} keys %$table_options);
	}

	my(@output) = "<table$table>";

	if ($#$headers >= 0)
	{
		push @output, '<thead>';
		push @output, '<th>' . join('</th><th>', @$headers) . '</th>' if ($#$headers >= 0);
		push @output, '</thead>';
	}

	for my $row (0 .. $#$data)
	{
		push @output, '<tr><td>' . join('</td><td>', map{defined($_) ? $_ : ''} @{$$data[$row]}) . '</td></tr>';
	}

	if ($#$footers >= 0)
	{
		push @output, '<tfoot>';
		push @output, '<th>' . join('</th><th>', @$footers) . '</th>' if ($#$footers >= 0);
		push @output, '<tfoot>';
	}

	push @output, '</table>';

	return [@output];

} # End of render_as_html.

# ------------------------------------------------

1;

=pod

=head1 NAME

C<Text::Table::Manifold> - Render tables in manifold styles

=head1 Synopsis

This is scripts/synopsis.pl:

	#!/usr/bin/env perl

	use strict;
	use warnings;

	use Text::Table::Manifold ':constants';

	# -----------

	my($table) = Text::Table::Manifold -> new;

	$table -> headers(['Name', 'Type', 'Null', 'Key', 'Auto increment']);
	$table -> data(
	[
		['id', 'int(11)', 'not null', 'primary key', 'auto_increment'],
		['description', 'varchar(255)', 'not null', '', ''],
		['name', 'varchar(255)', 'not null', '', ''],
		['upper_name', 'varchar(255)', 'not null', '', ''],
		[undef, '', '', '', ''],
	]);
	$table -> alignment(justify_center);
	$table -> empty(empty_as_minus);
	$table -> undef(undef_as_text);
	$table -> padding(1);
	$table -> style(as_boxed);

	print "Style: as_boxed: \n";
	print join("\n", @{$table -> render}), "\n";
	print "\n";

	$table -> style(as_github);

	print "Style: as_github: \n";
	print join("\n", @{$table -> render}), "\n";
	print "\n";

This is the output of synopsis.pl:

	Style: as_boxed:
	+-------------+--------------+----------+-------------+----------------+
	|    Name     |     Type     |   Null   |     Key     | Auto increment |
	+-------------+--------------+----------+-------------+----------------+
	|     id      |   int(11)    | not null | primary key | auto_increment |
	| description | varchar(255) | not null |      -      |       -        |
	|    name     | varchar(255) | not null |      -      |       -        |
	| upper_name  | varchar(255) | not null |      -      |       -        |
	|    undef    |      -       |    -     |      -      |       -        |
	+-------------+--------------+----------+-------------+----------------+

	Style: as_github:
	Name|Type|Null|Key|Auto increment
	-----------|------------|--------|-----------|--------------
	id|int(11)|not null|primary key|auto_increment
	description|varchar(255)|not null|-|-
	name|varchar(255)|not null|-|-
	upper_name|varchar(255)|not null|-|-
	undef|-|-|-|-

=head1 Description

Renders your data as tables of various types:

=over 4

=item o as_boxed

All headers and table data are surrounded by ASCII characters.

=item o as_github

As github-flavoured markdown.

=item o as_html

As a HTML table.

=back

See data/*.log for output corresponding to scripts/*.pl.

See the L</FAQ> for various topics, including:

=over 4

=item o UFT8 handling

See scripts/utf8.pl and data/utf8.log.

=back

=head1 Distributions

This module is available as a Unix-style distro (*.tgz).

See L<http://savage.net.au/Perl-modules/html/installing-a-module.html>
for help on unpacking and installing distros.

=head1 Installation

Install L<Text::Table::Manifold> as you would any C<Perl> module:

Run:

	cpanm Text::Table::Manifold

or run:

	sudo cpan Text::Table::Manifold

or unpack the distro, and then either:

	perl Build.PL
	./Build
	./Build test
	sudo ./Build install

or:

	perl Makefile.PL
	make (or dmake or nmake)
	make test
	make install

=head1 Constructor and Initialization

C<new()> is called as C<< my($parser) = Text::Table::Manifold -> new(k1 => v1, k2 => v2, ...) >>.

It returns a new object of type C<Text::Table::Manifold>.

Key-value pairs accepted in the parameter list (see corresponding methods for details
[e.g. L</data([$arrayref])>]):

=over 4

=item o alignment => An imported constant

A value for this parameter is optional.

Alignment applies equally to every cell in the table.

See the L</FAQ> for details.

Default: justify_center.

=item o data => $arrayref of arrayrefs

An arrayref of arrayrefs, each one a line of data.

The # of elements in each row must match the # of elements in the C<headers> arrayref (if any).

See the L</FAQ> for details.

A value for this parameter is optional.

Default: [].

=item o empty => An imported constant

A value for this parameter is optional.

See the L</FAQ> for details.

Default: empty_as_empty. I.e. do not transform.

=item o padding => $integer

A value for this parameter is optional.

See the L</FAQ> for details.

Default: 0.

=item o pass_thru => $hashref

A hashref of values to pass thru to another object.

See the L</FAQ> for details.

Default: {}.

=item o style => An imported constant

A value for this parameter is optional.

See the L</FAQ> for details.

Default: as_boxed.

=item o undef => An imported constant

A value for this parameter is optional.

See the L</FAQ> for details.

Default: undef_as_undef.

=back

=head1 Methods

=head2 alignment([$alignment])

Here, the [] indicate an optional parameter.

Returns the alignment as a constant (actually an integer).

$alignment might force spaces to be added to one or both sides of a cell value.

Alignment applies equally to every cell in the table.

This happens before any spaces specified by L</padding([$integer])> are added.

See the L</FAQ#What are the constants for alignment?> for legal values for $alignment.

=head2 data([$arrayref])

Here, the [] indicate an optional parameter.

Returns the data as an arrayref. Each element in this arrayref is an arrayref of one row of data.

The structure of C<$arrayref>, if provided, must match the description in the previous line.

Rows do not need to have the same number of elements.

Use Perl's C<undef> or '' (the empty string) for missing values.

See L</empty([$empty])> and L</undef([$undef])> for how '' and C<undef> are handled.

=head2 empty([$empty])

Here, the [] indicate an optional parameter.

Returns the option specifying how empty cell values ('') are being dealt with.

$empty controls how empty strings in cells are rendered.

See the L</FAQ#What are the constants for handling cell values which are empty strings?>
for legal values for $empty.

See also L</undef([$undef])>.

=head2 headers([$arrayref])

Here, the [] indicate an optional parameter.

Returns the headers as an arrayref of strings.

$arrayref, if provided, must be an arrayref of strings.

The # of elements in $arrayref does not have to match the # of elements in each row of the data,
but really, it should.

=head2 new([%hash])

The constructor. See L</Constructor and Initialization> for details of the parameter list.

Note: L</render([%hash])> supports the same options as C<new()>.

=head2 padding([$integer])

Here, the [] indicate an optional parameter.

Returns the padding as an integer.

Padding is the # of spaces to add to both sides of the cell value after it has been aligned.

=head2 pass_thru([$hashref])

Here, the [] indicate an optional parameter.

Returns the hashref previously provided.

The structure of this hashref is detailed in the L</FAQ>.

See scripts/synopsis.pl for sample code where it is used to add attributes to the C<table> tag in
HTML output.

=head2 render([%hash])

Here, the [] indicate an optional parameter.

Returns an arrayref, where each element is 1 line of the output table. These lines do not have "\n"
or any other line terminator (e.g. <br/>) added by this module.

It's up to you how to handle the output. The simplest thing is to just do:

	print join("\n", @{$table -> render}), "\n";

Note: C<render()> supports the same options as L</new([%hash])>.

=head2 style([$style])

Here, the [] indicate an optional parameter.

Returns the style as a constant (actually an integer).

See the L</FAQ#What are the constants for styling?> for legal values for $style.

=head2 undef([$undef])

Here, the [] indicate an optional parameter.

Returns the option specifying how undef cell values are being dealt with.

$undef controls how undefs in cells are rendered.

See the L</FAQ#What are the constants for handling cell values which are undef?>
for legal values for $undef.

See also L</empty([$empty])>.

=head1 FAQ

Note: See L</TODO> for what has not been implemented yet.

=head2 How are imported constants used?

Firstly, you must import them with:

	use Text::Table::Manifold ':constants';

Then you can use them in the constructor:

	my($table) = Text::Table::Manifold -> new(alignment => justify_center);

And/or you can use them in method calls:

	$table -> style(as_boxed);

See scripts/synopsis.pl for various use cases.

Note how the code uses the names of the constants. The integer values listed below are just FYI.

=head2 What are the constants for styling?

The C<style> option must be one of the following:

=over 4

=item o as_boxed  => 0

=item o as_github => 1

=item o as_html   => 2

=back

=head2 What are the constants for alignment?

The C<alignment> option must be one of the following:

=over 4

=item o justify_left  => 0

=item o justify_left  => 1

=item o justify_right => 2

=back

Alignment applies equally to every cell in the table.

=head2 What are the constants for handling cell values which are empty strings?

The C<handle_empty> option must be one of the following:

=over 4

=item o empty_as_empty => 0

Do nothing.

This is the default.

=item o empty_as_minus => 1

Convert empty cell values to '-'.

=item o empty_as_text  => 2

Convert empty cell values to the text string 'empty'.

=item o empty_as_undef => 3

Convert empty cell values to undef.

=back

Warning: This updates the original data!

=head2 What are the constants for handling cell values which are undef?

The C<handle_undef> option must be one of the following:

=over 4

=item o undef_as_empty => 0

Convert undef cell values to the empty string ('').

=item o undef_as_minus => 1

Convert undef cell values to '-'.

=item o undef_as_text  => 2

Convert undef cell values to the text string 'undef'.

=item o undef_as_undef => 3

Do nothing.

This is the default.

=back

Warning: This updates the original data!

=head2 How do I run author tests?

This runs both standard and author tests:

	shell> perl Build.PL; ./Build; ./Build authortest

=head1 TODO

=over 4

=item o Fancy alignment of real numbers

It makes sense to right-justify integers, but in the rest of the table you probably want to
left-justify strings.

Then, vertically aligning decimal points (whatever they are in your locale) is another complexity.

=item o Embedded newlines

Cell values which are HTML could be split at each "<br/>" and "<br />" for the same reason.

Cell values which are text could be split at each "\n" character, to find the widest line within the
cell. That is then used as the cell's width.

For Unicode, this is complex. See L<http://www.unicode.org/versions/Unicode7.0.0/ch04.pdf>, and
especially p 192, for 'Line break' controls. Also, the Unicode line breaking algorithm is documented
in L<http://www.unicode.org/reports/tr14/tr14-33.html>.

Perl modules relevant to this are listed under L</See also#Line Breaking>.

=item o Nested tables

This really requires the implementation of embedded newline analysis, as per the previous point.

=item o Pass-thru class support

Initially, L<HTML::Table>, L<PDF::Table> and L<Text::CSV> will be supported. The problem is the
mixture of options required to drive other classes.

=item o Sorting the rows, or individual columns

See L<Data::Table> and L<HTML::Table>.

=item o Color support

See L<Text::ANSITable>.

=back

=head1 See Also

=head2 Table Rendering

L<Any::Renderer>

L<Data::Formatter::Text>

L<Data::Tab>

L<Data::Table>

L<Data::Tabulate>

L<Gapp::TableMap>

L<HTML::Table>

L<HTML::Tabulate>

L<LaTeX::Table>

L<Text::ASCIITable>

L<PDF::Table>

L<PDF::TableX>

L<PDF::Report::Table>

L<Table::Simple>

L<Term::TablePrint>

L<Text::ANSITable>

L<Text::ASCIITable>

L<Text::CSV>

L<Text::FormatTable>

L<Text::MarkdownTable>

L<Text::SimpleTable>

L<Text::Table>

L<Text::Table::Tiny>

L<Text::TabularDisplay>

L<Text::Tabulate>

L<Text::UnicodeBox>

L<Text::UnicodeBox::Table>

L<Text::UnicodeTable::Simple>

L<Tie::Array::CSV>

=head2 Line Breaking

L<Text::Format>

L<Text::LineFold>

L<Text::NWrap>

L<Text::Wrap>

L<Text::WrapI18N>

=head1 Machine-Readable Change Log

The file Changes was converted into Changelog.ini by L<Module::Metadata::Changes>.

=head1 Version Numbers

Version numbers < 1.00 represent development versions. From 1.00 up, they are production versions.

=head1 Repository

L<https://github.com/ronsavage/Text-Table-Manifold>

=head1 Support

Email the author, or log a bug on RT:

L<https://rt.cpan.org/Public/Dist/Display.html?Name=Text::Table::Manifold>.

=head1 Author

L<Text::Table::Manifold> was written by Ron Savage I<E<lt>ron@savage.net.auE<gt>> in 2015.

Marpa's homepage: L<http://savage.net.au/Marpa.html>.

My homepage: L<http://savage.net.au/>.

=head1 Copyright

Australian copyright (c) 2014, Ron Savage.

	All Programs of mine are 'OSI Certified Open Source Software';
	you can redistribute them and/or modify them under the terms of
	The Artistic License 2.0, a copy of which is available at:
	http://opensource.org/licenses/alphabetical.

=cut
