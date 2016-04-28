#!/usr/bin/perl

use 5.010;

use strict;
use warnings;
no  warnings 'syntax';

use Test::More 0.88;

our $r = eval "require Test::NoWarnings; 1";

use Language::Funge::YAF;

my $yaf = Language::Funge::YAF:: -> new -> init;

isa_ok $yaf, "Language::Funge::YAF";


ok $yaf -> compile (<<"--"), "Single line program compiled";
  @  #
--

my $res = $yaf -> run;

pass "Program ran";
is $res, 1, "Expected return value";


Test::NoWarnings::had_no_warnings () if $r;

done_testing;
