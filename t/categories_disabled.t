#!/usr/bin/env perl

use strict;
use warnings;
no warnings qw(uninitialized);

use Test::More;

use_ok('warnings::everywhere');

# At first, no warning categories are disabled
is_deeply([warnings::everywhere::categories_disabled()],
    [], 'No warnings are enabled at first');

done_testing();
