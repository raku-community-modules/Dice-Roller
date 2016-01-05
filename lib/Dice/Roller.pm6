unit class Dice::Roller;

# Grammar defining a dice string:-
# ------------------------------

grammar DiceGrammar {
	token         TOP { ^ <roll> $ }
	token        roll { <quantity> <die> }
	token    quantity { \d+ }
	token         die { d(\d+) }
}

# Other classes we use internally to represent the parsed dice string:-
# -------------------------------------------------------------------

class Die {
	has Int $.faces;	# All around me different faces I see
}

# Actions used to build our internal representation from the grammar:-
# ------------------------------------------------------------------

class DiceActions {
	method TOP($/) {
		make $<roll>.made;
	}
	method roll($/) {
		make { quantity => $<quantity>.made, die => $<die>.made };
	}
	method quantity($/) {
		make $/.Int;
	}
	method die($/) {
		make Die.new( faces => $0.Int );
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
	my Match $match = DiceGrammar.parse($string, :actions(DiceActions));
	say "Parsed: ", $match.gist;
	return self.bless(string => $string, parsed => $match.made);
}

# Note that in general, doing extra constructor work should happen in the BUILD submethod; doing our own
# special new method here may complicate things in subclasses. But we do want a nice simple constructor,
# and defining our own 'new' seems to be the best way to accomplish this.
# http://doc.perl6.org/language/objects#Object_Construction


