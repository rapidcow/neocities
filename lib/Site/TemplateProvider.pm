package Site::TemplateProvider;

use strict;
use warnings;
use parent 'Template::Provider';
use Cwd qw(abs_path);
use Template::Constants qw(STATUS_ERROR);
use RdKw::WwW::GenGenLib qw(read_deps);
use Site::Deps qw(norm_path walk_deps);

# One provider per render.  The entry source declares the complete set of
# files the render may read, and Site::Deps adds what the templates it names
# declare in turn.  Declarations are compared as normalized paths (norm_path),
# so ${a}/include/NAME and include/NAME are the same file; a template found as
# DIR/NAME in INCLUDE_PATH is looked up as that path.  D is config.mk.
sub new {
	my ($class, $args) = @_;
	my $D = $args->{D} or die "render: D (the configuration) is required\n";
	my $self = $class->SUPER::new({ %$args, ABSOLUTE => 1 });
	return unless $self;
	my $source = $self->_resolve($args->{SOURCE});
	die "render: source `$args->{SOURCE}' not found\n" unless defined $source;
	my %deps = read_deps($source);
	$self->{D} = $D;
	die "render: $source must declare HAVE: @{[ $self->_spell(norm_path($D, $source)) ]}\n"
		unless defined $deps{HAVE}
			&& eval { norm_path($D, $deps{HAVE}) eq norm_path($D, $source) };
	$self->{ENTRY} = $source;
	$self->{ALLOWED} = { norm_path($D, $source) => 1 };
	$self->{ALLOWED}{ norm_path($D, $_) } = 1
		for eval { walk_deps($D, $source, $args->{GRAPH}) };
	die "render: $source: $@" if $@;
	return $self;
}

# Template names are plain relative paths.
sub _safe_name {
	my ($name) = @_;
	return defined($name) && !ref($name)
		&& $name =~ m{\A[\w.-]+(?:/[\w.-]+)*\z}
		&& $name !~ m{(?:\A|/)\.{1,2}(?:/|\z)};
}

# Use the normal search order, then authorize that exact file. Do not skip
# an undeclared file in an earlier directory to find an allowed namesake.
sub _resolve {
	my ($self, $name) = @_;
	return unless _safe_name($name);
	for my $dir (@{ $self->{INCLUDE_PATH} }) {
		my $path = "$dir/$name";
		return $path if -f $path;
	}
	return;
}

# A path as a header would say it: under ${a}, symbolically.
sub _spell {
	my ($self, $path) = @_;
	my $a = $self->{D}{a};
	return "\${a}/$path" if $a eq '.';
	return "\${a}/" . substr($path, length($a) + 1) if index($path, "$a/") == 0;
	return $path;
}

sub _authorized {
	my ($self, $name) = @_;
	return (undef, "invalid template name") unless _safe_name($name);
	my $path = $self->_resolve($name);
	return (undef, "template not found") unless defined $path;
	my $dep = norm_path($self->{D}, $path);
	my $spelt = $self->_spell($dep);
	return (undef, "undeclared dependency `$spelt'; add NEED: $spelt to $self->{ENTRY}")
		unless $self->{ALLOWED}{$dep};
	return (abs_path($path), undef);
}

sub fetch {
	my ($self, $name) = @_;
	my ($path, $error) = $self->_authorized($name);
	return ("$name: $error", STATUS_ERROR) if defined $error;
	return $self->SUPER::fetch($path);
}

# INSERT uses load rather than fetch; enforce the same declaration there.
sub load {
	my ($self, $name) = @_;
	my ($path, $error) = $self->_authorized($name);
	return ("$name: $error", STATUS_ERROR) if defined $error;
	return $self->SUPER::load($path);
}

1;
