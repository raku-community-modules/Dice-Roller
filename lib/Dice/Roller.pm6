unit class Dice::Roller;

# Attributes of a Dice::Roller:-

has Str $.string is required;


# Other classes we use internally to represent the parsed dice string:-

class Die {
	has Int $.faces;	# All around me different faces I see
}
