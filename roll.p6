#!/usr/bin/env perl6

use v6;
use lib 'lib';
use Dice::Roller;

my $dice = Dice::Roller.new('1d20');
say $dice.perl;