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

#
# Really trivial program; we're not going to run it.
#
$yaf -> compile (<<"--");
@
--

$yaf -> init_stack;

is $yaf -> top_stack, 0, "Pop an empty stack";
is $yaf -> pop_stack, 0, "Pop an empty stack";

my @out = $yaf -> pop_stack (3);

is_deeply \@out, [0, 0, 0], "Multipop from empty stack";


$yaf -> push_stack (123);

is $yaf -> top_stack, 123, "Pushed element on stack";
is $yaf -> pop_stack, 123, "Pop pushed element from stack";
is $yaf -> top_stack,   0, "Stack is empty again";


$yaf -> push_stack (1, 1, 2, 3, 5, 8);
is $yaf -> top_stack, 8, "Pushed multiple elements on stack";
@out = $yaf -> pop_stack (3);
is_deeply \@out, [3, 5, 8], "Multipop from stack";
is $yaf -> top_stack, 2, "Popped elements are gone from stack";
@out = $yaf -> pop_stack (5);
is_deeply \@out, [0, 0, 1, 1, 2], "Pop more than stack has";
is $yaf -> pop_stack, 0, "Stack is empty";

Test::NoWarnings::had_no_warnings () if $r;

done_testing;
