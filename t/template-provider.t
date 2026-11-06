use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use Cwd qw(getcwd);
use FindBin;
use lib "$FindBin::Bin/../lib";
use Template;
use Site::TemplateProvider;
use Template::Constants qw(STATUS_ERROR);

my $cwd = getcwd();
my $dir = tempdir(CLEANUP => 1);
chdir $dir or die $!;
mkdir $_ or die $! for qw(site temple include);

sub write_file {
	my ($path, $text) = @_;
	open my $fh, '>', $path or die "$path: $!";
	print {$fh} $text;
	close $fh or die $!;
}

sub provider {
	Site::TemplateProvider->new({
		SOURCE => 'entry', INCLUDE_PATH => [qw(site temple include)],
	});
}

sub render {
	my ($headers, $body, $vars) = @_;
	write_file('site/entry', "[%\n # HAVE: \${a}/site/entry\n$headers-%]\n$body");
	my $tt = Template->new({ LOAD_TEMPLATES => [provider()] });
	my $output = '';
	my $ok = $tt->process('entry', $vars || {}, \$output);
	return ($ok, $output, $tt->error());
}

write_file('include/allowed', 'allowed');
write_file('include/secret', 'secret');
my ($ok, $out, $err) = render(" # NEED: \${a}/include/allowed\n", '[% INCLUDE allowed %]');
ok($ok, 'declared INCLUDE works');
is($out, 'allowed', 'header does not affect output');

for my $directive (qw(INCLUDE PROCESS WRAPPER INSERT)) {
	my $body = "[% $directive secret %]";
	$body .= '[% END %]' if $directive eq 'WRAPPER';
	($ok, $out, $err) = render('', $body);
	ok(!$ok, "$directive rejects undeclared file");
	like("$err", qr{undeclared dependency `\$\{a\}/include/secret'}, 'error names dependency');
}

($ok, $out) = render('', '[% BLOCK local %]local[% END %][% INCLUDE local %]');
ok($ok, 'local BLOCK needs no file declaration');
is($out, 'local', 'local BLOCK renders');

($ok, $out) = render(" # NEED: \${a}/include/allowed\n", '[% INCLUDE $chosen %]', {chosen => 'allowed'});
ok($ok, 'dynamic declared include works');
($ok, $out, $err) = render('', '[% INCLUDE $chosen %]', {chosen => 'secret'});
ok(!$ok, 'dynamic undeclared include fails');

write_file('include/outer', '[% INCLUDE secret %]');
($ok, $out, $err) = render(" # NEED: \${a}/include/outer\n", '[% INCLUDE outer %]');
ok(!$ok, 'nested load must be declared by entry source');
($ok, $out) = render(" # NEED: \${a}/include/outer \${a}/include/secret\n", '[% INCLUDE outer %]');
ok($ok, 'explicit nested dependency works');
is($out, 'secret', 'nested template rendered');

($ok, $out) = render(" # NEED: \${B}/\${b}/built.css\n # WANT: \${a}/include/absent\n", 'optional');
ok($ok, 'built NEED and unused WANT are allowed');

eval { render(" # NEED: ../include/allowed\n", 'x') };
like($@, qr/invalid NEED\/WANT path/, 'dot components rejected in declarations');

write_file('site/entry', "[%\n # HAVE: wrong\n-%]\n");
eval { provider() };
like($@, qr{must declare HAVE: \$\{a\}/site/entry}, 'HAVE must identify actual source');

write_file('site/entry', "[%\n # HAVE: \${a}/site/entry\n # NEED: \${a}/include/allowed\n-%]\n");
my $p = provider();
my ($data, $status) = $p->fetch('allowed');
ok(!$status, 'initial fetch succeeds');
delete $p->{ALLOWED}{'${a}/include/allowed'};
($data, $status) = $p->fetch('allowed');
is($status, STATUS_ERROR, 'cached fetch still checks authorization');
for my $name ('../include/allowed', "$dir/include/allowed", './allowed') {
	($data, $status) = $p->fetch($name);
	is($status, STATUS_ERROR, "reject path alias $name");
}

write_file('site/allowed', 'shadow');
$p = provider();
($data, $status) = $p->fetch('allowed');
is($status, STATUS_ERROR, 'earlier undeclared namesake cannot bypass allowlist');
like($data, qr{undeclared dependency `\$\{a\}/site/allowed'}, 'shadow error identifies actual resolved path');

chdir $cwd or die $!;
done_testing;
