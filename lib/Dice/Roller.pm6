unit class Dice::Roller;

# Grammar defining a dice string:-
# ------------------------------

grammar DiceGrammar {
	token                  TOP { ^ <expression> [ ';' \s* <expression> ]* ';'? $ }

	proto token         add_op {*}
	rule            expression { <term> [ <add_op> <term> ]* }
	rule                  term { <roll> | <modifier> }
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
class Die {
	has Int $.faces;		# All around me different faces I see
	has @.distribution;	# We will use this when rolling; this allows for non-linear dice to be added later.
	has $.value is rw;	# Which face is showing, if any?

	submethod BUILD(:$!faces) {
		# Initialise the distribution of values with a range of numbers from 1 to the number of faces the die has.
		@!distribution = 1..$!faces;
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
class Modifier {
	has Int $.value is required;

	method total returns Int {
		return $!value;
	}

	method Str {
		return $!value >= 0 ?? "+$!value" !! "-$!value";
	}
}

# A roll of one or more polyhedra, with some rule about how we combine them.
class Roll {
	has Int $.quantity;
	has Die @.dice;
	has Modifier @.modifiers;

	method roll {
		@!dice».roll;
	}

	method set-max {
		@!dice».set-max;
	}

	method set-min {
		@!dice».set-min;
	}

	method is-max returns Bool {
		return @!dice.all.is-max.Bool;
	}

	method is-min returns Bool {
		return @!dice.all.is-min.Bool;
	}

	method total returns Int {
		return [+] (@!dice».total, @!modifiers».total).flat;
	}

	method Str {
		if any(@!dice».value) {
			# one or more dice have been rolled, we don't need to prefix our quantity, they'll have literal values.
			return join('', @!dice) ~ join('', @!modifiers);
		} else {
			# no dice have been rolled, we return a more abstract representation.
			return $!quantity ~ @!dice[0] ~ join('', @!modifiers);
		}
	}
}


class Expression {
	has @.values
}


# Actions used to build our internal representation from the grammar:-
# ------------------------------------------------------------------

class DiceActions {
	method TOP($/) {
		# .parse returns an array of Expression objects with this Actions object,
		# one entry for each of the roll expressions separated by ';' in the string.
		make $<roll>».made;
	}
	method expression($/) {
		say "EXPRESSION! ", join(', ', $/.caps);
	}
	method add_op:sym<+>($/) {
		say "ADD_OP<+>! ", join(', ', $/.caps);
	}
	method add_op:sym<->($/) {
		say "ADD_OP<->! ", $/;
	}
	method term($/) {
		say "TERM! ", $/;
	}
	method roll($/) {
		# While there is only one 'die' token within the 'roll' grammar, we actually want
		# to construct the Roll object with multiple Die objects as appropriate, so that
		# we can roll and remember the face value of individual die.
		my Int $quantity = $<quantity>.made;
		my Die @dice = (1..$quantity).map({ $<die>.made.clone });
		my Modifier @modifiers = $<modifier>».made;
		make Roll.new( :$quantity, :@dice, :@modifiers );
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
has $.parsed is required;

# We define a custom .new method to allow for positional (non-named) parameters:-
method new(Str $string) {
	my $match = DiceGrammar.parse($string, :actions(DiceActions));
	die "Failed to parse '$string'!" unless $match;
	say "Parsed: ", $match.gist;
	return self.bless(string => $string, parsed => $match.made);
}

# Note that in general, doing extra constructor work should happen in the BUILD submethod; doing our own
# special new method here may complicate things in subclasses. But we do want a nice simple constructor,
# and defining our own 'new' seems to be the best way to accomplish this.
# http://doc.perl6.org/language/objects#Object_Construction


method roll {
	$!parsed».roll;
	return self;
}

method set-max {
	$!parsed».set-max;
	return self;
}

method set-min {
	$!parsed».set-min;
	return self;
}

method is-max returns Bool {
	return $!parsed.all.is-max.Bool;
}

method is-min returns Bool {
	return $!parsed.all.is-min.Bool;
}

method total returns Int {
	return [+] self.group-totals;
}

method group-totals returns Array {
	return $!parsed».total;
}

method Str {
	return join('; ', $!parsed.flat);
}

