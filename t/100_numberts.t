#!/usr/bin/perl

use 5.010;

use strict;
use warnings;
no  warnings 'syntax';

use feature  'signatures';
no  warnings 'experimental::signatures';

use Test::More 0.88;

our $r = eval "require Test::NoWarnings; 1";

use Language::Funge::YAF;

my $yaf = Language::Funge::YAF:: -> new -> init;

isa_ok $yaf, "Language::Funge::YAF";


sub run_tests ($program, $name, $ret_val_exp = 0) {
    subtest $name => sub {
        ok $yaf -> compile ($program), "Program compiled";
        my $ret_val_got = $yaf -> run;
        is $ret_val_got, $ret_val_exp, "Return value ok";
    }
}


run_tests <<"--", "Read single digit number", 7;
 7 @
--

run_tests <<"--", "Read multi digit number", 123;
 123 @
--

run_tests <<"--", "Read multiple numbers", 764;
 123 #
    7
  @ 6
 #  4
    #
--

run_tests <<"--", "Looping numbers", -3;
    1#
    7
  @ 6
 #  4
--


run_tests <<"--", "Numbers after a turn", 7;
 1#
 7
 @
--


Test::NoWarnings::had_no_warnings () if $r;

done_testing;
