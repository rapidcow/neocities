package Hack::TextWrap;

use 5.010;
use strict;
use warnings;
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(text_wrap);

use List::BisectSearch qw/bisect/;

# set this to 1 to debug
our $debug = 0;

# okay, this is a rather ambitious attempt that failed
# miserably.... but here's how it's supposed to work:
#
# $limit: line length
# $pre: the indent we don't see
# $post: the last word we don't see (XXX: seems broken)
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
	# indent for line > 0: this is a hard-coded constant
	my $indent = 3;
	# limit from line 1 and on (the first line is line 0 :)
	# minus one (see how $offset is computed)
	my $limit1 = $limit - $indent;
	my $needle = 0;       # which word are we looking at?
	my $offset = -$pre;   # where was that word?  (for the first
	# line, i am artificially flushing $pre against the 0 marker
	# ... it's weird i know, but this is for the math to work @_@)

	# IMPORTANT IMPORTANT! if there is any worth in this
	# code at all, it would be these two arrays.
	#
	# crucially both of these represent ranges; e.g. char count
	# is $sizes[$needle] - $sizes[$needle - 1] for $needle >= 1
	# (for word count, swap @points in...)
	my @points = (0);
	my @sizes = (-$pre);

	while ($needle < @words) {
		# find upper bound for how much we can fit on this line
		my $stride = bisect { !(
			# rule for every word but last: plus one to
			# account for the space in most circumstances
			# (plus two because of backslash + space.....)
			$total[$_] - $offset + 1 + 2 <= $limit ||
			# rule for the last word because this algorithm
			# is stupid, and... aesthetics? :)
			$_ == $#total && $total[$_] - $offset <= $total[$_]
		) } $needle, scalar (@total);
		# eat at least one word
		$needle += $stride - $needle || 1;
		push @points, $needle;
		# switch to new limit after first iteration
		$limit = $limit1;
		# take $offset in the stupidest possible way
		# (this stupid doesn't even know the space
		# turned into a LF :<)
		# btw: https://www.perlmonks.org/?node_id=564792
		$offset = $total[$needle - 1] - !!($needle == @words);
		push @sizes, $offset;
	}

	# ***HEURISTICS***
	# balance the last two lines out (i.e. minimize the absolute
	# difference between the last line and the first line)
	# admittedly, this *will* look horrendous for 3+ lines,
	# but think git commit messages.... they're not that long
	# ethan -- don't overthink it :)
	if (@points - 1 >= 2) {
		# here is a simple example of moving one word from line 1 to line 2:
		# if ($points[1] > 0) {
		# 	$points[1] -= 1;
		# 	$sizes[1] += $total[$points[1] - 1] - $total[$points[1]];
		# }
		# (note the intentional decrement before retrieving the length of
		# the word at $points[1], due to the exclusive nature of bounds)
		# to do this multiple times, we'll generalize this in a way that
		# the ABSOLUTE difference between
		#
		#     ($sizes[2] - $sizes[1] + $indent)
		#                and           ^^^^^^^ (adjustment for 3-space indent)
		#     ($sizes[1] - $sizes[0] + 2)
		#                              ^ (adjustment for space + backslash)
		#
		# is minimized, after adjustment, by moving $points[1] to, say,
		# "$points[1] - best".  then the above code becomes:
		# my $best = 6;
		# if ($best > $points[1]) {
		# 	print STDERR "WARNING: you are shifting too much.\n"
		# } elsif ($best > 0) {
		# 	$points[1] -= 1;
		# 	$sizes[1] += ($points[1] <= $best
		# 		? $total[$points[1] - $best] : 0)
		# 		- $total[$points[1]];
		# 	$points[1] -= $best - 1;
		# }
		# observe that we step down by one first, as before, but we move
		# as many as we need INCLUDING OURSELVES, then we seal the case
		# in the end.  (the ternary operator is there in case this range
		# is left-exclusive, and so if the first word is included, then
		# we want to indicate that this range starts with 0 characters.)
		#
		# (huh.  maybe this should be a function.  who knows.
		# anyways....)
		my $best = 0;
		my $best_score = ($sizes[1] - $sizes[0] + 2) - ($sizes[2] - $sizes[1] + $indent);
		# prefer short-LONG layout to LONG-short
		for (my $i = $points[1]; $i > 0; --$i) {
			my $refpt = $points[1] - 1;
			# they're all supposed to be NEGATIVE !!!
			my $delta = ($refpt >= $i ? $total[$refpt - $i] : 0) - $total[$refpt];
			die "$delta\n" unless $delta < 0;
			my $score = ($sizes[1] - $sizes[0] + 2 + $delta) - ($sizes[2] - $sizes[1] + $indent - $delta);
			if (abs ($score) < abs ($best_score)) {
				$best = $i;
				$best_score = $score;
			}
		}
		# if ($best > $points[1]) {
		# 	print STDERR "WARNING: you are shifting too much.\n"
		die if $best > $points[1];
if ($debug) {
		print "I figured that $best is best for you ...\n";
}
		if ($best > 0) {
			$points[1] -= 1;
			$sizes[1] += ($points[1] <= $best
				? $total[$points[1] - $best] : 0)
				- $total[$points[1]];
			$points[1] -= $best - 1;
		}
	}

	# here's a little something to visualize what we've got.
	# (this actually sneaks the output into HTML, wink wink ;)
if ($debug) {
	print "\n"; # you likely want this
	print "-" x 72, "\n";
	print "visual size:\n";
	for (1..$#points) {
		# plus two for space and backslash
		# or plus $post on final line...
		my $extra = $_ == $#points ? $post : 2;
		$extra += $indent if $_ > 1;
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
}

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
