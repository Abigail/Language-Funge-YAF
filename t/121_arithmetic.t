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


sub run_tests ($program, $name, $output_exp = "", $ret_val_exp = 0) {
    subtest $name => sub {
        ok $yaf -> compile ($program), "Program compiled";
        open my $fh, ">", \(my $output = "");
        my $old_fh = select $fh;
        my $ret_val_got = $yaf -> run;
        select $old_fh;
        is $ret_val_got, $ret_val_exp, "Return value ok";
        is $output, $output_exp, "Output ok";
    }
}


run_tests <<"--", "Adding multiple numbers", "100";
 21 32 44 3+++.@
--


run_tests <<"--", "Multiplying crossing numbers", "52521";
    #
   1   #
.*724   #@
  #3    #
   #   #
--

run_tests <<"--", "Negative result", "-8";
 12 7 + 11 - . @
--


run_tests <<"--", "Work with an empty stack", "0";
 +++.@
--

run_tests <<"--", "Divide by zero", "", -4;
 0 6 / . @
--



Test::NoWarnings::had_no_warnings () if $r;

done_testing;
