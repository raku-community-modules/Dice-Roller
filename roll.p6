#!/usr/bin/env perl6

use v6;
use lib 'lib';
use Dice::Roller;

sub show($dice) {
	say "Rolled '" ~ $dice.string ~ "'",
	    " and " ~ critmaybe($dice) ~ ": " ~ $dice,
       " totals=" ~ $dice.group-totals;
}

# whether something is a 'crit' or not is kind of dependent on the system,
# but we can test for "all rolled faces show the maximum".
sub critmaybe($dice) {
	given $dice {
		when .is-max { "crit!" }
		when .is-min { "fumbled!" }
		default { "got" }
	}
}

show(Dice::Roller.new('1d20 + 3').roll);
show(Dice::Roller.new('3d4 + 1; 2d6').roll);

my $total = 0;
$total += Dice::Roller.new('3d6').roll.total;
say "Running total is $total";
$total += Dice::Roller.new('3d6').roll.total;
say "Running total is $total";
