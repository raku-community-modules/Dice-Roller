#!/usr/bin/env perl6

use v6;
use lib 'lib';
use Dice::Roller;

my $dice = Dice::Roller.new('3d6+4; 1d4');
$dice.roll;
say "Rolled '" ~ $dice.string ~ "' and got: " ~ $dice ~ " total=" ~ $dice.total;
