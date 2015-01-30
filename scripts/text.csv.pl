#!/usr/bin/env perl

use strict;
use warnings;

use Text::Table::Manifold ':constants';

# -----------

my($table) = Text::Table::Manifold -> new
(
	alignment =>
	[
		align_left,
		align_center,
		align_right,
		align_center,
	]
);

$table -> headers(['Homepage', 'Country', 'Name', 'Metadata']);
$table -> data(
[
	['http://savage.net.au/',   'Australia', 'Ron Savage',    undef],
	['https://duckduckgo.com/', 'Earth',     'Mr. S. Engine', ''],
]);

# Note: Save the data, since render() may update it.

my(@data) = @{$table -> data};

$table -> format(format_text_csv);
$table -> pass_thru({format_text_csv => {always_quote => 1} });

print "Format: format_text_csv: \n";
print join("\n", @{$table -> render}), "\n";
print "\n";

# Note: Restore the saved data.

$table -> data([@data]);

# Etc.
