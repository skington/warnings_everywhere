#!/usr/bin/env perl
# Check that trying to pass any old nonsense to the unimport syntax
# fails.

use strict;
use warnings;
use Test::Fatal;
use Test::More qw(no_plan);

my $use = 'no warnings::everywhere';
is(eval("$use [qw(foo bar baz)]; 1"), undef, 
    'Cannot pass an arrayref to import');
is(eval("$use {}; 1"), undef, 'Cannot pass an empty hashref');
diag 'Expect a warning "Unrecognised warning category bees" here';
is(eval("$use {warning => 'bees', thwart_module => 'Foo'}; 1"), undef,
    'Must specify a valid warning');
