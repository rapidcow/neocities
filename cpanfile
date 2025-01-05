# CPAN requirements for Carmel
# https://metacpan.org/pod/Carmel
requires 'Template';
requires 'HTML::Tiny';
requires 'Git';
# Perl - you are amazing qvq
requires 'HTML::FromANSI::Tiny';
# My first package!
####requires 'List::BisectSearch', '== 0.01',
####  url => 'https://codeberg.org/rapidcow/list-bisectsearch/archive/v0.01.tar.gz';
# does not work :(
# install it yourself....
# cpan App::cpanminus LWP::Protocol::https &&
# cpanm 'https://codeberg.org/rapidcow/list-bisectsearch/archive/v0.01.tar.gz'
#   OR
# git clone ~/my/project/dist/perl5/List-BisectSearch vendor && cd vendor &&
# perl Makefile.PL && make && make install
