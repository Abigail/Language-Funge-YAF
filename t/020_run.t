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


sub run_tests ($program, $name, $ret_val_exp = 1) {
    subtest $name => sub {
        ok $yaf -> compile ($program), "Program compiled";
        my $ret_val_got = $yaf -> run;
        is $ret_val_got, $ret_val_exp, "Return value ok";
    }
}


run_tests <<"--", "Really simple program";
  @  #
--

run_tests <<"--", "Program with corner";
   #

  @
--

run_tests <<"--", "Program with multiple corners";
   #   @

 #      #
  #
--

run_tests <<"--", "Program is walled in", -2;
 #
#
--

Test::NoWarnings::had_no_warnings () if $r;

done_testing;
