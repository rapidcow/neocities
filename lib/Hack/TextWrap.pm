package Hack::TextWrap;

use 5.010;
use strict;
use warnings;
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(text_wrap);

use List::BisectSearch qw/bisect/;

# okay, this is a rather ambitious attempt that failed
# miserably.... but here's how it's supposed to work:
#
# $limit: line length
# $pre: the indent we don't see
# $post: the last word we don't see
# $text: text to wrap
#
# the goal is to have a                 as a purely greedy approach would
# balanced paragraph layout:            produce very uneven margins...
#
# [   pre   ]  _________                [  pre  ] _______________________
# ______________________                ______________ [ post ]
# _____________ [ post ]
#
# but this is way harder to write than i thought, well...
# at least i know that binary search works in perl now :)
#
sub text_wrap {
	use integer;
	my ($limit, $pre, $post, $text) = @_;
	my @words = split ' ', $text;
	return '' unless @words;
	my @total = ();

	my $count = 0;
	for my $word (@words) {
		$count += length $word;
		push @total, $count;
		$count += 1;
	}

	# i don't know what to do with this.....
	push @total, $count + $post if $post;

	# save the initial limit
	my $limit0 = $limit;
	# limit from line 1 and on (the first line is line 0 :)
	# minus one (see how $offset is computed)
	my $limit1 = $limit - 2;
	my $needle = 0;       # which word are we looking at?
	my $offset = -$pre;   # where was that word?  (for the first
	# line, i am artificially flushing $pre against the 0 marker
	# ... it's weird i know, but this is for the math to work @_@)

	# IMPORTANT IMPORTANT! if there is any worth in this
	# code at all, it would be these two arrays.
	#
	# crucially both of these are ranges,
	my @points = (0);
	my @sizes = (-$pre);

	while ($needle < @words) {
		# plus one to account for the space in most
		# circumstances (except for the last - because
		# this algorithm is stupid, and... aesthetics? :)
		#
		# (plus two because of backslash + space.....)
		my $stride = bisect { !($total[$_] - $offset + 1 + 2 <= $limit ||
			$_ == $#total && $total[$_] - $offset <= $total[$_]) }
			$needle, scalar (@total);
		# eat at least one word
		$needle += $stride - $needle || 1;
		push @points, $needle;
		$limit = $limit1;
		# take $offset in the stupidest possible way
		# (this stupid doesn't even know the space
		# turned into a LF :<)
		# btw: https://www.perlmonks.org/?node_id=564792
		$offset = $total[$needle - 1] - !!($needle == @words);
		push @sizes, $offset;
	}

	# here's a little something to visualize what we've got.
	# (this actually sneaks the output into HTML, wink wink ;)
	print "\n"; # you likely want this
	print "-" x 72, "\n";
	print "visual size:\n";
	for (1..$#points) {
		# plus two for space and backslash
		# or plus $post on final line...
		my $extra = $_ == $#points ? $post : 2;
		# printf behaves weirdly (TT2 doesn't like it?);
		# so do this..... as a workaround (:
		print sprintf ("  %d..%d (%d word%s, %d%s%d = %d%s char%s)\n",
			$points[$_-1], $points[$_], $points[$_] - $points[$_-1],
			"s" x!! ($points[$_] - $points[$_-1] - 1),
			$sizes[$_],
			$sizes[$_-1] < 0 ? ("+", -$sizes[$_-1]) : ("-", $sizes[$_-1]),
			$sizes[$_] - $sizes[$_-1],
			"(+$extra)" x!! $extra,
			"s" x!! ($sizes[$_] - $sizes[$_-1] - $extra - 1),
		);
	}
	print "-" x 72, "\n";

	my $linenum = 0;
	my $wordnum = 0;
	my @buffer;
	for ($wordnum = 0; $wordnum < @words; $wordnum++) {
		if ($wordnum < $points[$linenum + 1]) {
			push @buffer, ' ' if $wordnum;
		} else {
			push @buffer, " \\\n";
			push @buffer, ' ' x 3;
			$linenum++;
		}
		push @buffer, $words[$wordnum];
	}

	return join '', @buffer;
}

1;
