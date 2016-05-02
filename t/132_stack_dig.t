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


run_tests <<'--', "Dig into stack", "68754";
 4 5 6 7 8 3 \.....@
--

run_tests <<'--', "Repeated digging into stack", "87654";
 4 5 6 7 8 3\3\3\.....@
--

run_tests <<'--', "Bury into stack", "87654";
 4 5 6 7 8 3 0 - \.....@
--


Test::NoWarnings::had_no_warnings () if $r;

done_testing;
