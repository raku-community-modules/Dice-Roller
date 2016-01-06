unit class Dice::Roller;

# Grammar defining a dice string:-
# ------------------------------

grammar DiceGrammar {
	token         TOP { ^ <roll> [ ';' \s* <roll> ]* ';'? $ }
	token        roll { <quantity> <die> \s* <modifier>* \s* }
	token    quantity { \d+ }
	token         die { d(\d+) }
	token    modifier { ('+' | '-') \s* (\d+) \s* }
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
	}

	method Str {
		return "[$!value]" if $!value;
		return "(d$!faces)";
	}
}

# Some fixed value adjusting a roll's total outcome.
class Modifier {
	has Int $.value is required;

	method Str {
		return $!value >= 0 ?? "+$!value" !! "-$!value";
	}
}

# A roll of one or more polyhedra, with some rule about how we combine them.
class Roll {
	has Int $.quantity;
	has Die $.die;
	has Modifier @.modifiers;

	method roll {
		$!die.roll;
	}

	method Str {
		return $!quantity ~ $!die [~] @!modifiers;
	}
}


# Actions used to build our internal representation from the grammar:-
# ------------------------------------------------------------------

class DiceActions {
	method TOP($/) {
		# .parse returns an array of Roll objects with this Actions object.
		make $<roll>».made;
	}
	method roll($/) {
		make Roll.new( quantity => $<quantity>.made, die => $<die>.made, modifiers => $<modifier>».made );
	}
	method quantity($/) {
		make $/.Int;
	}
	method die($/) {
		make Die.new( faces => $0.Int );
	}
	method modifier($/) {
		make Modifier.new( value => "$0$1".Int );
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
	$!parsed».roll();
}

method Str {
	$!parsed.Str;
}

