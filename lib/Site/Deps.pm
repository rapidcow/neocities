package Site::Deps;

use strict;
use warnings;
use Exporter 'import';
use File::Spec;
# norm_deps is 0.00_02
use RdKw::WwW::GenGenLib 0.0002 qw(read_deps norm_deps);

our @EXPORT_OK = qw(norm_path walk_deps);

# Dependencies are spelled symbolically (${a}/temple/x, ${B}/${b}/x.css) or
# written out as the variables expand (temple/x, ../build/public/x.css, which
# is what "${D.B}/${D.b}/x.css" gives).  norm_path puts either in one spelling,
# a canonical path from the project root, and refuses what must not be read:
# a dot component (${B}/${b}/../../etc/passwd) that is not part of a variable's
# own value, an absolute path that no variable leads to, an unknown variable.
#
# \%D is config.mk (A a B b c); ${A} is always `.' here (the root).

sub _vars {
	my ($D) = @_;
	return (A => '.', map { $_ => $D->{$_} } grep { defined $D->{$_} } qw(a B b c));
}

sub _literal_ok {
	my ($seg) = @_;
	return $seg =~ /\A[\w.-]+\z/ && $seg ne '.' && $seg ne '..';
}

sub norm_path {
	my ($D, $spec) = @_;
	die "norm_path: empty path\n" unless defined $spec && !ref $spec && length $spec;
	return $spec =~ /\$/ ? _norm_symbolic($D, $spec) : _norm_verbatim($D, $spec);
}

sub _norm_symbolic {
	my ($D, $spec) = @_;
	my %var = _vars($D);
	my $norm = norm_deps($spec);	# ${A}/ prefix gone, braces everywhere
	$norm = '.' unless length $norm;
	my (@part, $prev);
	for my $seg (grep { length } split m{/}, $norm) {
		if ($seg =~ /\A\$\{(\w+)\}\z/) {
			my $x = $1;
			exists $var{$x} or die "invalid path `$spec': no such variable \${$x}\n";
			die "invalid path `$spec': \${$x} is relative to \${B}; write \${B}/\${$x}\n"
				if ($x eq 'b' || $x eq 'c') && !(defined $prev && $prev eq 'B');
			push @part, $var{$x};
			$prev = $x;
		} elsif (_literal_ok($seg)) {
			push @part, $seg;
			$prev = undef;
		} else {
			die "invalid path `$spec': bad component `$seg'\n";
		}
	}
	return File::Spec->canonpath(join '/', @part);
}

# Which part of the string came from a variable cannot be known, so look for
# a variable's value at the front, and hold the rest to the literal rules.
sub _norm_verbatim {
	my ($D, $spec) = @_;
	my $path = File::Spec->canonpath($spec);
	return $path if $path eq '.';
	my %var = _vars($D);
	my @root = grep { $_ ne '.' } map { File::Spec->canonpath($_) } (
		(defined $var{a} ? $var{a} : ()),
		(defined $var{B} ? $var{B} : ()),
		(defined $var{B} && defined $var{b} ? "$var{B}/$var{b}" : ()),
		(defined $var{B} && defined $var{c} ? "$var{B}/$var{c}" : ()),
	);
	my ($best) = sort { length $b <=> length $a }
		grep { $path eq $_ || index($path, "$_/") == 0 } @root;
	my $rest = defined $best ? substr($path, length $best) : $path;
	die "invalid path `$spec': absolute, and not under any of the configured trees\n"
		if !defined $best && File::Spec->file_name_is_absolute($path);
	for my $seg (grep { length } split m{/}, $rest) {
		_literal_ok($seg) or die "invalid path `$spec': bad component `$seg'\n";
	}
	return $path;
}

# The deps of a header, as written.  Files we make (and anything that is not
# a plain text file) have none.
sub _direct {
	my ($D, $path, $built) = @_;
	return [] if grep { $path eq $_ || index($path, "$_/") == 0 } @$built;
	return [] unless -f $path && -T _;
	my %I = read_deps($path);
	return [ @{ $I{NEED} || [] }, @{ $I{WANT} || [] } ];
}

# All that FILE needs, and those need, ... : as written, unsubstituted, in
# depth-first order, each file once however it is spelled (that is why the
# cycles stop).  NEED or WANT makes no difference to a list of files that may
# be read; one that is not there is listed, and not read.  Run norm_path on the
# results.
#
# %G caches what each file says, by norm_path name; give the same one to the
# next walk and no file is read twice.
sub walk_deps {
	my ($D, $file, $G) = @_;
	$G ||= {};
	my $root = norm_path($D, $file);
	my @built = grep { $_ ne '.' } map { File::Spec->canonpath($_) } (
		map { "$D->{B}/$D->{$_}" } grep { defined $D->{$_} } qw(b c));
	my (@out, %seen);
	$seen{$root} = 1;
	my @stack = ([ $root, 0 ]);
	while (@stack) {
		my $f = $stack[-1];
		my $deps = $G->{ $f->[0] } ||= _direct($D, $f->[0], \@built);
		if ($f->[1] >= @$deps) {
			pop @stack;
			next;
		}
		my $spec = $deps->[ $f->[1]++ ];
		my $path = eval { norm_path($D, $spec) };
		die "$f->[0]: $@" unless defined $path;
		next if $seen{$path}++;
		push @out, $spec;
		push @stack, [ $path, 0 ];
	}
	return @out;
}

1;
