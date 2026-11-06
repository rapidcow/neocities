package Site::Deps;

use strict;
use warnings;
use Exporter 'import';
use File::Spec;
use RdKw::WwW::GenGenLib ();
use RdKw::WwW::GenGenLib qw(split_dep subs_deps);

our @EXPORT_OK = qw(norm_path walk_deps);

# The variables are ours (\%D is config.mk) but the files that name paths in
# their headers may not be.  A dependency is split into its symbolic root and
# the rest (split_dep, which promises nothing about safety); only these roots
# may be named, and the rest may not climb out of one.
#
#   built   ${B} ${B}/${b} ${B}/${c}    listed, never read for a header
#   source  (none) ${a} ${tem} ${inc}   read, and followed
my @BUILT = ('${B}', '${B}/${b}', '${B}/${c}');

sub _source_roots {
	my ($D) = @_;
	return ('', '${a}', map { defined $D->{$_} ? "\${$_}" : () } qw(tem inc));
}

# ('built' | 'source'), or dies.
sub _kind {
	my ($D, $spec) = @_;
	die "invalid path: empty\n" unless defined $spec && !ref $spec && length $spec;
	my ($root, $rest) = split_dep($spec);
	my $kind = (grep { $_ eq $root } @BUILT) ? 'built'
		: (grep { $_ eq $root } _source_roots($D)) ? 'source' : undef;
	die "invalid path `$spec': root `$root' is not allowed\n" unless defined $kind;
	# a variable we do not have would expand to nothing, and move the file
	for my $x ($rest =~ /\$\{(\w+)\}/g) {
		die "invalid path `$spec': no such variable \${$x}\n" unless defined $D->{$x};
	}
	my $name = subs_deps($D, $rest);
	die "invalid path `$spec': leaves its root (absolute, or has a `..')\n"
		if $name =~ m{\A/} || $name =~ m{(?:\A|/)\.\.(?:/|\z)};
	return $kind;
}

# The path from the project root, canonical, or dies.  Equal specs may
# spell it differently (${a}/x, site/x); this is what makes them the same.
sub norm_path {
	my ($D, $spec) = @_;
	_kind($D, $spec);
	return File::Spec->canonpath(subs_deps($D, $spec));
}

# Everything FILE needs, and those need, ... as written (symbolic), for
# norm_path.  Only what has a source root is read.  \%G caches headers.
sub walk_deps {
	my ($D, $file, $G) = @_;
	return RdKw::WwW::GenGenLib::walk_deps($D, $file, {
		graph => ($G || {}),
		follow => sub { my $kind = eval { _kind(@_) }; defined $kind && $kind eq 'source' },
	});
}

1;
