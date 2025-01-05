package List::BisectSearch;
# Perl doesn't have double-ended binary search?!?
# shocking....
use 5.006;
use strict;
use warnings;
# not until we turn this into a library...
#### use Scalar::Util;

# how to export things:
# https://perldoc.perl.org/Exporter#SYNOPSIS
require Exporter;
our @ISA = qw( Exporter );
our @EXPORT_OK = qw( bisect bisect0 bisect1 bisect2 );

sub bisect (&$$) {
	my ($ok, $lo, $hi) = @_;

	#
	#   F F F T ... T
	#  lo     _     hi
	#         ^
	while ($lo < $hi) {
		my $mid = $lo + (($hi - $lo) >> 1);
		local *_ = \$mid;
		if (&$ok) {
			$hi = $mid;
		} else {
			$lo = $mid + 1;
		}
	}
	return $lo;
}

# here are a few "useful" applications
sub bisect0 (&$$) {
	my ($compar, $array, $target) = @_;
	my $caller = caller (); # closure hack!
	no strict 'refs';
	# https://fastapi.metacpan.org/source/DAVIDO/List-BinarySearch-0.25/lib/List/BinarySearch/PP.pm
	return bisect {
		local (${"${caller}::a"}, ${"${caller}::b"}) = ($array->[$_], $target);
		&$compar >= 0;
	} 0, scalar @$array;
}

sub bisect1 (&$$) {
	my ($compar, $array, $target) = @_;
	my $caller = caller (); # closure hack again!
	no strict 'refs';
	return bisect {
		local (${"${caller}::a"}, ${"${caller}::b"}) = ($array->[$_], $target);
		&$compar > 0;
	} 0, scalar @$array;
}

sub bisect2 (&$$) {
	my ($compar, $array, $target) = @_;
	my $caller = caller (); # well....
	no strict 'refs';
	my $lower = bisect {
		local (${"${caller}::a"}, ${"${caller}::b"}) = ($array->[$_], $target);
		&$compar >= 0;
	} 0, scalar @$array;
	my $upper = bisect {
		local (${"${caller}::a"}, ${"${caller}::b"}) = ($array->[$_], $target);
		&$compar > 0;
	} $lower, scalar @$array;
	return ($lower, $upper);
}

1;
