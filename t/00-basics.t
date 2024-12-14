use Test;

use Dice::Roller;

plan 4;

# Can we parse a simple expression and return a valid object?
my $dice = Dice::Roller.new('1d20');
isa-ok $dice, 'Dice::Roller';

# Initial stringified state is blank
is $dice, "1(d20)", "Initial state is 1d20";

# Can be rolled to get some number (obviously nondeterministic so I won't check for a specific one...)
isa-ok $dice.roll.total, Int, "Dice can be rolled and totalled";

# We can set dice to their maximum value
is $dice.set-max.total, 20, "Dice can be set to max value";

# vim: expandtab shiftwidth=4
