use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use Cwd qw(getcwd);
use FindBin;
use lib "$FindBin::Bin/../lib";
use Site::Deps qw(norm_path walk_deps);

my %D = (A => '.', a => 'src', B => '../build', b => 'public', c => '.cache');

is(norm_path(\%D, '${B}/${b}/base.css'), '../build/public/base.css', 'symbolic');
is(norm_path(\%D, '$B/$b/base.css'), '../build/public/base.css', 'braceless variables');
is(norm_path(\%D, '../build/public/base.css'), '../build/public/base.css', 'written out');
is(norm_path(\%D, "${\ $D{B}}/$D{b}/base.css"), '../build/public/base.css', 'interpolated');
is(norm_path(\%D, '${a}/temple/x'), 'src/temple/x', 'symbolic source');
is(norm_path(\%D, 'src/temple/x'), 'src/temple/x', 'verbatim source');
is(norm_path(\%D, 'temple/x'), 'temple/x', 'bare name is from the root');
is(norm_path(\%D, '${A}/temple/x'), 'temple/x', '${A} prefix is the root');
is(norm_path({ %D, B => '.' }, './public/x.css'), 'public/x.css', 'dot-slash from B=.');

for my $bad ('${B}/${b}/../../etc/passwd', '../build/public/../../etc/passwd',
		'${a}/../x', 'src/../x', '/etc/passwd', '../x', '${nope}/x',
		'${b}/x', '${a}x/y', 'a/${B}z') {
	ok(!defined eval { norm_path(\%D, $bad) }, "rejects $bad");
}
like($@, qr/bad component/, 'says why');

my $cwd = getcwd();
my $dir = tempdir(CLEANUP => 1);
chdir $dir or die $!;
sub w { my ($f, $t) = @_; (my $d = $f) =~ s{/[^/]*\z}{}; system 'mkdir', '-p', $d if $d ne $f;
	open my $fh, '>', $f or die; print $fh $t; close $fh or die }
my %E = (A => '.', a => 'site', B => '.', b => 'public', c => '.cache');
w('site/index.html', "[%\n # HAVE: \${a}/site/index.html\n # NEED: temple/head.html\n # WANT: \${B}/\${b}/x.css\n-%]\n");
w('temple/head.html', "[%\n # NEED: \${B}/\${b}/base.css\n # NEED: \${a}/../etc\n-%]\n");
{
	local $@;
	ok(!defined eval { walk_deps(\%E, 'site/index.html') }, 'a bad dep stops the walk');
	like($@, qr{temple/head\.html: invalid path}, '... naming whose header');
}
w('temple/head.html', "[%\n # NEED: \${B}/\${b}/base.css\n # NEED: \${A}/temple/other.html\n-%]\n");
w('temple/other.html', "[%\n # NEED: temple/head.html\n # WANT: gone/file\n-%]\n");
w('public/x.css', "# NEED: should/not/be/read\n");
my %G;
my @d = walk_deps(\%E, 'site/index.html', \%G);
is_deeply(\@d, ['temple/head.html', '${B}/${b}/base.css', '${A}/temple/other.html',
	'gone/file', '${B}/${b}/x.css'], 'depth first, as written, cycle stopped');
ok(!exists $G{'public/x.css'} || !@{ $G{'public/x.css'} }, 'what we make is not read');
my @e = walk_deps(\%E, '${a}/index.html', \%G);
is_deeply(\@e, \@d, 'cached walk from a symbolic start');
chdir $cwd;
done_testing;
