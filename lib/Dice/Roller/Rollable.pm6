unit role Dice::Roller::Rollable;

# "Abstract interface" for all rollable Dice::Roller objects.

# For the Role to help out with the tedious stuff, classes should implement something
# that returns all of its Rollable sub-objects. That way the default implementations
# of these methods will Just Work.
method contents returns Array[Dice::Roller::Rollable] { ... }

# Roll any dice contained in this Rollable, setting them to new random values.
method roll {
	self.contents».roll;
	return self;
}

