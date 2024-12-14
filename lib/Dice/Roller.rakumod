use Dice::Roller::Rollable;
use Dice::Roller::Selector;

unit class Dice::Roller does Dice::Roller::Rollable;

our $debug = False;	# Accessible as $Dice::Roller::debug;

# Grammar defining a dice string:-
# ------------------------------

grammar DiceGrammar {
	token                  TOP { ^ <expression> [ ';' \s* <expression> ]* ';'? $ }

	proto rule      expression {*}
	proto token         add_op {*}
	proto token       selector {*}

	rule   expression:sym<add> { <add_op>? <term> [ <add_op> <term> ]* }
	token                 term { <roll> | <modifier> }
	token        add_op:sym<+> { <sym> }
	token        add_op:sym<-> { <sym> }

	regex                 roll { <quantity> <die> <selector>* }
	token             quantity { \d+ }
	token                  die { d(\d+) }
   token     selector:sym<kh> { ':' <sym>(\d+) }    # keep highest n
   token     selector:sym<kl> { ':' <sym>(\d+) }    # keep lowest n
   token     selector:sym<dh> { ':' <sym>(\d+) }    # drop highest n
   token     selector:sym<dl> { ':' <sym>(\d+) }    # drop lowest n

	regex             modifier { (\d+) }
}

# Other classes we use internally to represent the parsed dice string:-
# -------------------------------------------------------------------

# A single polyhedron.
class Die does Dice::Roller::Rollable {
	has Int $.faces;		# All around me different faces I see
	has @.distribution;	# We will use this when rolling; this allows for non-linear dice to be added later.
	has $.value is rw;	# Which face is showing, if any?

	submethod BUILD(:$!faces) {
		# Initialise the distribution of values with a range of numbers from 1 to the number of faces the die has.
		@!distribution = 1..$!faces;
	}

	method contents {
		[]
	}
	
	method roll {
		$!value = @.distribution.pick;
		self
	}

	method set-max {
		$!value = @.distribution.max;
		self
	}

	method set-min {
		$!value = @.distribution.min;
		self
	}

	method is-max returns Bool {
		$!value == @.distribution.max
	}

	method is-min returns Bool {
		$!value == @.distribution.min
	}

	method total returns Int {
		$!value // 0
	}

	method Num {
		$!value
	}

	method Str {
        $!value ?? "[$!value]" !! "(d$!faces)"
	}
}


# Some fixed value adjusting a roll's total outcome.
class Modifier does Dice::Roller::Rollable {
	has Int $.value is required;

	method contents()       { []          }
	method is-max(--> True) {             }
	method is-min(--> True) {             }
	method total(--> Int:D) { $!value     }
	method Str(--> Str:D)   { $!value.Str }
}

# A thing that selects or adjusts certain dice from a Roll.
# In this case, we want to keep the highest num rolls.
class KeepHighest does Dice::Roller::Selector {
	has Int $.num = 1;

	method select ($roll) {
		my $keep = $.num min $roll.dice.elems;
		my $drop = $roll.dice.elems - $keep;
		say "Selecting highest $keep rolls (dropping $drop) from '$roll'" if $debug;
		my @removed = $roll.sort.dice.splice(0, $drop);	# Replace 0..^drop with empty
		say "Discarding: " ~ @removed if $debug;
	}
}

class KeepLowest does Dice::Roller::Selector {
	has Int $.num = 1;

	method select ($roll) {
		my $keep = $.num min $roll.dice.elems;
		my $drop = $roll.dice.elems - $keep;
		say "Selecting lowest $keep rolls (dropping $drop) from '$roll'" if $debug;
		my @removed = $roll.sort.dice.splice($keep);	# Replace keep..* with empty
		say "Discarding: " ~ @removed if $debug;
	}
}

class DropHighest does Dice::Roller::Selector {
	has Int $.num = 1;

	method select ($roll) {
		my $drop = $.num min $roll.dice.elems;
		my $keep = $roll.dice.elems - $drop;
		say "Dropping highest $drop rolls (keeping $keep) from '$roll'" if $debug;
		my @removed = $roll.sort.dice.splice($keep);	# Replace keep..* with empty
		say "Discarding: " ~ @removed if $debug;
	}
}

class DropLowest does Dice::Roller::Selector {
	has Int $.num = 1;

	method select ($roll) {
		my $drop = $.num min $roll.dice.elems;
		my $keep = $roll.dice.elems - $drop;
		say "Dropping lowest $drop rolls (keeping $keep) from '$roll'" if $debug;
		my @removed = $roll.sort.dice.splice(0, $drop);	# Replace 0..^drop with empty
		say "Discarding: " ~ @removed if $debug;
	}
}

# A roll of one or more polyhedra, with some rule about how we combine them.
class Roll does Dice::Roller::Rollable {
	has Int $.quantity;
	has Die @.dice is rw;
	has Dice::Roller::Selector @.selectors;

	method contents {
		@.dice
	}

	method roll {
		@!dice».roll;
		for @!selectors -> $selector {
			$selector.select(self);
		}
		self
	}

	# One thing that most Rollables don't do that's useful for Roll to be able to do,
	# sort the $.dice in ascending order - primarily so Selectors can do their work.
	# This sorts in-place.
	method sort {
		@!dice = @!dice.sort: { $^a.value cmp $^b.value };
		self
	}

	method Str {
		if any(@!dice».value) {
			# one or more dice have been rolled, we don't need to prefix our quantity, they'll have literal values.
			join('', @!dice)
		} else {
			# no dice have been rolled, we return a more abstract representation.
			$!quantity ~ @!dice[0]
		}
	}
}


class Expression does Dice::Roller::Rollable {
	has Pair @.operations;

	method contents {
		@!operations».value
	}

	method add(Str $op, Dice::Roller::Rollable $value) {
		@!operations.push( $op => $value );
	}

	# Expression needs to reimplement Total since we can now subtract parts of the roll.
	method total(--> Int:D) {
		my $total = 0;
		for @!operations -> $op-pair {
			given $op-pair.key {
				when '+' { $total += $op-pair.value.total }
				when '-' { $total -= $op-pair.value.total }
				default  { die "unhandled Expression type " ~ $op-pair.key }
			}
		}
		$total
	}

	method Str(--> Str:D) {
		my Str $str = "";
		for @!operations -> $op-pair {
			$str ~= $op-pair.key if $str;
			$str ~= $op-pair.value;
		}
		$str
	}
}

# Because returning an Array of Expressions doesn't seem to be
# working well for us, let's stick the various (individual)
# rolls into one of these.
class RollSet does Dice::Roller::Rollable {
	has Dice::Roller::Rollable @.rolls;

	method contents { @!rolls }
	method group-totals(--> List:D) {
		@!rolls».total
	}

	method Str(--> Str:D) {
		join('; ', @!rolls)
	}
}

# Actions used to build our internal representation from the grammar:-
# ------------------------------------------------------------------

class DiceActions {
	method TOP($/) {
		# .parse returns a RollSet with an array of Expression objects,
		# one entry for each of the roll expressions separated by ';' in the string.
		make RollSet.new( rolls => $<expression>».made );
	}

	method expression:sym<add>($/) {
		my $expression = Expression.new;
		my Str $op = '+';

		for $/.caps -> Pair $term_or_op {
			given $term_or_op.key {
				when "term" { 
					my $term = $term_or_op.value;
					$expression.add($op, $term.made);
				}
				when "add_op" { 
					$op = $term_or_op.value.made;
				}
			}
		}
		make $expression;
	}

	method add_op:sym<+>($/) {
		make $/.Str;
	}

	method add_op:sym<->($/) {
		make $/.Str;
	}

	method term($/) {
		make $<roll>.made // $<modifier>.made;
	}

	method roll($/) {
		# While there is only one 'die' token within the 'roll' grammar, we actually want
		# to construct the Roll object with multiple Die objects as appropriate, so that
		# we can roll and remember the face value of individual die.
		my Int $quantity = $<quantity>.made;
		my Die @dice = (1..$quantity).map({ $<die>.made.clone });
		my Dice::Roller::Selector @selectors = $<selector>».made;

		make Roll.new( :$quantity, :@dice, :@selectors );
	}

	method quantity($/) {
		make $/.Int;
	}

	method die($/) {
		make Die.new( faces => $0.Int );
	}

	method modifier($/) {
		make Modifier.new( value => "$0".Int );
	}

	method selector:sym<kh>($/) {
		make KeepHighest.new( num => $0.Int );
	}

	method selector:sym<kl>($/) {
		make KeepLowest.new( num => $0.Int );
	}

	method selector:sym<dh>($/) {
		make DropHighest.new( num => $0.Int );
	}

	method selector:sym<dl>($/) {
		make DropLowest.new( num => $0.Int );
	}
}

# Attributes of a Dice::Roller:-
# ----------------------------

has Str $.string      is required;
has Match $.match     is required;
has RollSet $.rollset is required;


# We define a custom .new method to allow for positional (non-named) parameters:-
method new(Str $string) {
	my $match = DiceGrammar.parse($string, :actions(DiceActions));
	die "Failed to parse '$string'!" unless $match;
	#say "Parsed: ", $match.gist if $debug;
	self.bless(string => $string, match => $match, rollset => $match.made)
}

method contents { $!rollset }

method group-totals(--> List:D) {
	$!rollset.group-totals
}

method Str(--> Str:D) { $!rollset.Str }

=begin pod

=head1 NAME

Dice::Roller - Roll RPG-style polyhedral dice

=head1 SYNOPSIS

=begin code :lang<raku>

use Dice::Roller;

my $dice = Dice::Roller.new("2d6 + 1");
$dice.roll;
say $dice.total;    # 4. Chosen by fair dice roll.
$dice.set-max;
say $dice.total;    # 13

=end code

=head1 DESCRIPTION

Dice::Roller is the second of my forays into learning Raku. The aim
is simple - take a "dice string" representing a series of RPG-style
dice to be rolled, plus any modifiers, parse it, and get Raku to
virtually roll the dice involved and report the total.

It is still under development, but in its present form supports varied
dice expressions adding and subtracting fixed modifiers or additional
dice, as well as the "keep highest *n*" notations.
    
=head1 METHODS

=head2 new

=begin code :lang<raku>

my $dice = Dice::Roller.new('3d6 + 6 + 1d4');

=end code

C<.new> takes a single argument (a dice expression) and returns a
C<Dice::Roller> object representing that collection of dice.

The expression syntax used is the shorthand that is popular in RPG
systems; rolls of a group of similar dice are expressed as
<quantity>d<faces>, so 3d6 is a set of 3 six-sided dice, numbered
1..6. Additional groups of dice with different face counts can be
added and subtracted from the total, as well as fixed integer values.

Preliminary support for some "selectors" is being added, and are
appended to the dice identifier; rolling '4d6:kh3' stands for roll
4 d6, then keep the highest 3 dice. Selectors supported are:

=item **:kh<n>** - keep the highest *n* dice from this group.
=item **:kl<n>** - keep the lowest *n* dice from this group.
=item **:dh<n>** - drop the highest *n* dice from this group.
=item **:dl<n>** - drop the lowest *n* dice from this group.

Selectors can be chained together, so rolling '4d6:dh1:dl1' will
drop the highest and lowest value dice.

=head2 roll

=begin code :lang<raku>

$dice.roll;

=end code

Sets all dice in the expression to new random face values. Returns
the C<Dice::Roller> object for convenience, so you can do:

=begin code :lang<raku>

say $dice.roll.total;

=end code

=head2 total

=begin code :lang<raku>

my $persuade-roll = Dice::Roller.new('1d20 -2').roll;
my $persuade-check = $persuade-roll.total;

=end code

Evaluates the faces showing on rolled dice including any adjustments
and returns an C<Int> total for the roll.

=head1 ERROR HANDLING

C<Dice::Roller.new> throws an exception if the string failed to parse.

This behaviour might change in a future release.

=head1 DEBUGGING

You can get the module to spew out a bit of debugging text by setting
C<Dice::Roller::debug = True>. You can also inspect the Match object ini
a given roll: C<say $roll.match.gist>;

=head1 AUTHOR

James Clark

=head1 COPYRIGHT AND LICENSE

Copyright 2016 - 2017 James Clark

Copyright 2024 Raku Community

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod

# vim: expandtab shiftwidth=4
