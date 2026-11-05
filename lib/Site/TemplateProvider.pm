package Site::TemplateProvider;

use strict;
use warnings;
use parent 'Template::Provider';
use Cwd qw(abs_path);
use Template::Constants qw(STATUS_ERROR);
use RdKw::WwW::GenGenLib qw(read_deps);

# One provider per render. The entry source declares the complete set of
# files the render may read, including files loaded by nested templates.
# Declared paths are kept exactly as written (e.g. ${a}/include/EPILOG.txt),
# just as siteconf reads them; a template found as DIR/NAME in INCLUDE_PATH
# is looked up as ${a}/DIR/NAME.
sub new {
	my ($class, $args) = @_;
	my $self = $class->SUPER::new({ %$args, ABSOLUTE => 1 });
	return unless $self;
	my $source = $self->_resolve($args->{SOURCE});
	die "render: source `$args->{SOURCE}' not found\n" unless defined $source;
	my $have = _symbolic($source);
	my %deps = read_deps($source);
	die "render: $source must declare HAVE: $have\n"
		unless defined $deps{HAVE} && $deps{HAVE} eq $have;
	$self->{ENTRY} = $source;
	$self->{ALLOWED} = { $have => 1 };
	for my $kind (qw(NEED WANT)) {
		for my $path (@{ $deps{$kind} || [] }) {
			die "render: $source: invalid $kind path `$path'; "
				. "use literal paths such as \${a}/include/NAME\n"
				unless _safe_dep($path);
			$self->{ALLOWED}{$path} = 1;
		}
	}
	return $self;
}

sub _symbolic { '${a}/' . $_[0] }

# Template names are plain relative paths.
sub _safe_name {
	my ($name) = @_;
	return defined($name) && !ref($name)
		&& $name =~ m{\A[\w.-]+(?:/[\w.-]+)*\z}
		&& $name !~ m{(?:\A|/)\.{1,2}(?:/|\z)};
}

# Declared paths: like names, but the first segment may be a ${x} variable
# (and ${B}/${b}/... has two).  Dot components are never allowed.
sub _safe_dep {
	my ($path) = @_;
	return defined($path) && !ref($path)
		&& $path =~ m{\A(?:\$\{\w+\}|[\w.-]+)(?:/(?:\$\{\w+\}|[\w.-]+))*\z}
		&& $path !~ m{(?:\A|/)\.{1,2}(?:/|\z)};
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

sub _authorized {
	my ($self, $name) = @_;
	return (undef, "invalid template name") unless _safe_name($name);
	my $path = $self->_resolve($name);
	return (undef, "template not found") unless defined $path;
	my $dep = _symbolic($path);
	return (undef, "undeclared dependency `$dep'; add NEED: $dep to $self->{ENTRY}")
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
