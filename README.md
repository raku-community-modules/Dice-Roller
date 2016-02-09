# NAME

Dice::Roller - Roll RPG-style polyhedral dice.

# SYNOPSIS

    use Dice::Roller;
    
    my $dice = Dice::Roller.new("2d6 + 1");
    $dice.roll;
    say $dice.total;    # 4. Chosen by fair dice roll.
    $dice.set-max;
    say $dice.total;    # 13

# DESCRIPTION

Dice::Roller is the second of my forays into learning Perl 6. The aim is simple - take a "dice string" representing a series of RPG-style dice to be rolled, plus any modifiers, parse it, and get Perl 6 to virtually roll the dice involved and report the total.

It is still under development, but in its present form supports varied dice expressions adding and subtracting fixed modifiers or additional dice, as well as the "keep highest *n*" notations.

# COPYRIGHT AND LICENCE

Copyright 2016 James Clark

Dice::Roller is Free Software; it is available under the Aristic Licence 2.0. See the LICENSE file for details.
