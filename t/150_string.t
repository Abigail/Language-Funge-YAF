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


run_tests <<'--', "Read a string", "Hello";
 "olleH"  ,,,,,  @
--

run_tests <<'--', "Read several strings", "Hello, world";
 ",olleH"  ,,,,,, 32 , "dlrow" ,,,,, @
--

run_tests <<'--', "Nothing special inside a string", 'H@l#o ';
 " o#l@H"  ,,,,,, @
   @
--


Test::NoWarnings::had_no_warnings () if $r;

done_testing;
