use Dice::Roller::Rollable;

unit class Dice::Roller does Dice::Roller::Rollable;

# Grammar defining a dice string:-
# ------------------------------

grammar DiceGrammar {
	token                  TOP { ^ <expression> [ ';' \s* <expression> ]* ';'? $ }

	proto rule      expression {*}
	proto token         add_op {*}

	rule   expression:sym<add> { <add_op>? <term> [ <add_op> <term> ]* }
	token                 term { <roll> | <modifier> }
	token        add_op:sym<+> { <sym> }
	token        add_op:sym<-> { <sym> }

	regex                 roll { <quantity> <die> }
	token             quantity { \d+ }
	token                  die { d(\d+) }
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
		return [];
	}
	
	method roll {
		$!value = @.distribution.pick;
		return self;
	}

	method set-max {
		$!value = @.distribution.max;
		return self;
	}

	method set-min {
		$!value = @.distribution.min;
		return self;
	}

	method is-max returns Bool {
		return $!value == @.distribution.max;
	}

	method is-min returns Bool {
		return $!value == @.distribution.min;
	}

	method total returns Int {
		return $!value // 0;
	}

	method Str {
		return "[$!value]" if $!value;
		return "(d$!faces)";
	}
}

# Some fixed value adjusting a roll's total outcome.
class Modifier does Dice::Roller::Rollable {
	has Int $.value is required;

	method contents {
		return [];
	}

	method is-max {
		return True;
	}

	method is-min {
		return True;
	}

	method total returns Int {
		return $!value;
	}

	method Str {
		return $!value.Str;
	}
}

# A roll of one or more polyhedra, with some rule about how we combine them.
class Roll does Dice::Roller::Rollable {
	has Int $.quantity;
	has Die @.dice;

	method contents {
		return @.dice;
	}

	method Str {
		if any(@!dice».value) {
			# one or more dice have been rolled, we don't need to prefix our quantity, they'll have literal values.
			return join('', @!dice);
		} else {
			# no dice have been rolled, we return a more abstract representation.
			return $!quantity ~ @!dice[0];
		}
	}
}


class Expression does Dice::Roller::Rollable {
	has Pair @.operations;

	method contents {
		return @!operations».value;
	}

	method add(Str $op, Dice::Roller::Rollable $value) {
		@!operations.push( $op => $value );
	}

	method Str {
		my Str $str = "";
		for @!operations -> $op-pair {
			$str ~= " " ~ $op-pair.key ~ ":" ~ $op-pair.value;
		}
	}
}


# Because returning an Array of Expressions doesn't seem to be working well for us,
# let's stick the various (individual) rolls into one of these.
class RollSet does Dice::Roller::Rollable {
	has Dice::Roller::Rollable @.rolls;

	method contents {
		return @!rolls;
	}

	method group-totals returns List {
		return @!rolls».total;
	}

	method Str {
		return join('; ', @!rolls».Str);
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
		say "ADDITION EXPRESSION! ";
		my $expression = Expression.new;
		my Str $op = '+';

		for $/.caps -> Pair $term_or_op {
			given $term_or_op.key {
				when "term" { 
					my $term = $term_or_op.value;
					say "  term, is going to be $op " ~ $term.made;
					$expression.add($op, $term.made);
				}
				when "add_op" { 
					$op = $term_or_op.value.made;
					say "  add_op, setting $op";
				}
			}
		}
		make $expression;
	}

	method add_op:sym<+>($/) {
		say "ADD_OP<+>! ", $/;
		make $/.Str;
	}

	method add_op:sym<->($/) {
		say "ADD_OP<->! ", $/;
		make $/.Str;
	}

	method term($/) {
		say "TERM! ", $/;
		make $<roll>.made // $<modifier>.made;
	}

	method roll($/) {
		# While there is only one 'die' token within the 'roll' grammar, we actually want
		# to construct the Roll object with multiple Die objects as appropriate, so that
		# we can roll and remember the face value of individual die.
		my Int $quantity = $<quantity>.made;
		my Die @dice = (1..$quantity).map({ $<die>.made.clone });
		make Roll.new( :$quantity, :@dice );
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
}

# Attributes of a Dice::Roller:-
# ----------------------------

# Attributes are all private by default, and defined with the '!' twigil. But using '.' instead instructs
# Perl 6 to define the $!string attribute and automagically generate a .string *accessor* that can be
# used publically. Note that this accessor will be read-only by default.

has Str $.string is required;
has RollSet $.rollset is required;

# We define a custom .new method to allow for positional (non-named) parameters:-
method new(Str $string) {
	my $match = DiceGrammar.parse($string, :actions(DiceActions));
	die "Failed to parse '$string'!" unless $match;
	say "Parsed: ", $match.gist;
	return self.bless(string => $string, rollset => $match.made);
}

# Note that in general, doing extra constructor work should happen in the BUILD submethod; doing our own
# special new method here may complicate things in subclasses. But we do want a nice simple constructor,
# and defining our own 'new' seems to be the best way to accomplish this.
# http://doc.perl6.org/language/objects#Object_Construction


method contents {
	return $!rollset;
}

method group-totals returns List {
	return $!rollset.group-totals;
}

method Str {
	return $!rollset.Str;
}

