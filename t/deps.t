use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use Cwd qw(getcwd);
use FindBin;
use lib "$FindBin::Bin/../lib";
use Site::Deps qw(norm_path walk_deps);

my %D = (A => '.', a => 'src', B => '../build', b => 'public', c => '.cache',
	tem => 'temple', inc => 'include', HTML => 'html');

# --- two spellings, one path
is(norm_path(\%D, '${B}/${b}/base.css'), '../build/public/base.css', 'built');
is(norm_path(\%D, '$B/$b/base.css'), '../build/public/base.css', 'braceless');
is(norm_path(\%D, '${B}/${c}/x'), '../build/.cache/x', 'cache tree');
is(norm_path(\%D, '${a}/index.html'), 'src/index.html', 'source');
is(norm_path(\%D, '${tem}/base/head.html'), 'temple/base/head.html', '${tem}');
is(norm_path(\%D, 'temple/base/head.html'), 'temple/base/head.html', '... and as written');
is(norm_path(\%D, '${inc}/EPILOG.txt'), 'include/EPILOG.txt', '${inc}');
is(norm_path(\%D, '${A}/include/x'), 'include/x', '${A} is the root');
is(norm_path(\%D, '${B}/${b}/hello.${HTML}'), '../build/public/hello.html', 'variable in the rest');
is(norm_path(\%D, '${a}-foo/f'), 'src-foo/f', 'a sibling is silly, not wrong');
is(norm_path({ %D, B => '.' }, '${B}/${b}/x.css'), 'public/x.css', 'B is .');

# --- what is refused
for my $bad (
	'${B}/${b}/../../etc/passwd', '${a}/../x', '${a}/x/../../y', '../x', 'a/../../x',
	'${tem}/../secret', '/etc/passwd', '${A}//etc/passwd', "$ENV{HOME}/x",
	'${nope}/x', '${a}/${nope}', '${b}/x', '${B}x/y', 'x/${B}/y',
	'${R}/x', '', '${B}/${b}/${a}/x/..',
) {
	ok(!defined eval { norm_path(\%D, $bad) }, "refuses `$bad'") or diag $bad;
}
like($@, qr/invalid path/, 'says so');
eval { norm_path(\%D, '${B}/${b}/../../etc/passwd') };
like($@, qr/leaves its root/, 'traversal named as such');
eval { norm_path(\%D, '${nope}/x') };
like($@, qr/root `\$\{nope\}' is not allowed/, 'an unknown root is not allowed');

# --- the walk reads source roots only, and holds every dep to the rules
my $top = tempdir(CLEANUP => 1);
my $cwd = getcwd();
sub w { my ($f, $t) = @_; (my $d = $f) =~ s{/[^/]*\z}{}; system 'mkdir', '-p', $d if $d ne $f;
	open my $fh, '>', $f or die; print $fh $t; close $fh or die }
sub hdr { my %h = @_; join '', "[%\n", (map { " # $_: $h{$_}\n" } sort keys %h), "-%]\n" }
mkdir "$top/proj" or die;
w("$top/secret", hdr(NEED => 'leaked'));
chdir "$top/proj" or die;
my %E = (A => '.', a => 'site', B => '.', b => 'public', c => '.cache', tem => 'temple', inc => 'include');
w('site/index.html', hdr(HAVE => '${a}/index.html',
	NEED => 'temple/head.html ${B}/${b}/base.css', WANT => '${a}/gone.html'));
w('temple/head.html', hdr(NEED => '${inc}/part.html', WANT => '${a}/index.html'));
w('include/part.html', hdr(NEED => 'temple/head.html leaf'));
w('leaf', '');
w('public/base.css', hdr(NEED => 'must-not-be-read'));
{
	my %G;
	my @d = walk_deps(\%E, 'site/index.html', \%G);
	is_deeply(\@d, ['site/index.html', 'temple/head.html', '${inc}/part.html', 'leaf', '${a}/index.html', '${B}/${b}/base.css', '${a}/gone.html'],
		'the entry first, then through templates; cycles stop');
	is_deeply([ map { norm_path(\%E, $_) } @d ],
		[qw(site/index.html temple/head.html include/part.html leaf site/index.html public/base.css site/gone.html)], 'all normalize');
	ok(!exists $G{'${B}/${b}/base.css'}, 'built is not read');
}
for my $evil ('../secret', '${a}/../secret', '${tem}/x/../../../secret', "$top/secret",
		'/etc/passwd', '${A}//etc/passwd', '${B}/${b}/../../../secret', '${other}/x') {
	w('site/evil.html', hdr(NEED => $evil));
	my %G;
	my @d = walk_deps(\%E, 'site/evil.html', \%G);
	ok(!exists $G{$evil}, "never read: $evil");
	ok(!(grep { $_ eq 'leaked' } @d), "leads nowhere: $evil");
	ok(!defined eval { norm_path(\%E, $_) }, "and norm_path refuses it: $evil") for $evil;
}
chdir $cwd;
done_testing;
