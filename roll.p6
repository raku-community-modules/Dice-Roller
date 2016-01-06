#!/usr/bin/env perl6

use v6;
use lib 'lib';
use Dice::Roller;

my $dice = Dice::Roller.new('3d6+4');
$dice.roll;
say $dice.Str;