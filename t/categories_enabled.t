#!/usr/bin/env perl

use strict;
use warnings;
no warnings qw(uninitialized);

use Test::More;

use_ok('warnings::everywhere');

# At first, all warning categories are enabled
my @all_warnings = grep { $_ ne 'all' } sort keys %warnings::Offsets;
is_deeply([warnings::everywhere::categories_enabled()],
    \@all_warnings, 'All warnings are enabled at first');

done_testing();
