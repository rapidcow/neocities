# polymorphism for the sake of using custom CSS classes...
package Poly::Ansi2Html;

use 5.010;
use strict;
use warnings;

# ANSI! yippee!!!
# have to subclass it first though....
# https://stackoverflow.com/a/185121
use HTML::FromANSI::Tiny;

our @ISA = qw(HTML::FromANSI::Tiny);
# merging maps... https://stackoverflow.com/a/41733541
my %CSS_TABLE = (
	(map {
		qw(
			black   red     green   yellow
			blue    magenta cyan    white
		)[$_] => "setaf-$_"
	} (0..7)),
	(map {
		qw(
			bright-black    bright-red      bright-green    bright-yellow
			bright-blue     bright-magenta  bright-cyan     bright-white
		)[$_] => "setaf-hi-$_"
	} (0..7)),
);

sub attr_to_class {
	my $self = shift;
	my $name = shift;
        exists $CSS_TABLE{$name} ? $CSS_TABLE{$name} : $name;
}

1;
