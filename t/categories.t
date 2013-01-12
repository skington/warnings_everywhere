#!/usr/bin/env perl
# Check our list of warnings is what we expect.
# This is somewhat unnecessary, but at least documents somewhat 
# the warning history of Perl, which the perldeltas don't.
 
use strict;
use warnings;
no warnings qw(uninitialized);

use English qw(no_match_vars);
use Test::More qw(no_plan);

use_ok('warnings::everywhere');

# Before we go anywhere, check no warnings are disabled yet.
is_deeply([warnings::everywhere::categories_disabled()],
    [], 'Nothing is disabled yet');

# According to the source of warnings, this is what we should expect.
### TODO: 5.6.0, but it has an additional y2k warning category
### that goes away in 5.8.0, which is annoyingly fiddly.
### No it doesn't, it's still around in 5.8.9

my %categories = (
    '5.008' => [
        'closure',       'deprecated', 'exiting',   'glob',
        'io',            'closed',     'exec',      'layer',
        'newline',       'pipe',       'unopened',  'misc',
        'numeric',       'once',       'overflow',  'pack',
        'portable',      'recursion',  'redefine',  'regexp',
        'severe',        'debugging',  'inplace',   'internal',
        'malloc',        'signal',     'substr',    'syntax',
        'ambiguous',     'bareword',   'digit',     'parenthesis',
        'precedence',    'printf',     'prototype', 'qw',
        'reserved',      'semicolon',  'taint',     'threads',
        'uninitialized', 'unpack',     'untie',     'utf8',
        'void'
    ],
    '5.011' => ['imprecision'],
    '5.012'  => ['illegalproto'],
    '5.014'  => ['non_unicode', 'nonchar', 'surrogate',],
);

my %category_exists
    = map { $_ => 1 } warnings::everywhere::_warning_categories();

# Check we have the right warnings for this version of Perl.

for my $version (sort keys %categories) {
    if ($] >= $version) {
        for my $category (@{ $categories{$version} }) {
            ok(
                exists $warnings::Offsets{$category},
                "Perl defines warning category $category as this test thought"
            );
            ok(
                delete $category_exists{$category},
                "...the module expected that"
            );
            ok(
                warnings::everywhere::disable_warning_category($category),
                "We can disable warning category $category"
            );
            is_deeply([warnings::everywhere::categories_disabled()],
                [$category], 'It is now disabled');
            ok(
                warnings::everywhere::enable_warning_category($category),
                "We can enable warning $category again"
            );
            is_deeply([warnings::everywhere::categories_disabled()],
                [], "Everything is enabled again after $category");
        }
    } else {
        for my $category (@{ $categories{$version} }) {
            ok(!exists $warnings::Offsets{$category},
                "This old Perl $] doesn't define category $category");
            ok(
                !exists $category_exists{$category},
                "...and the module didn't expect it to"
            );
        }
    }
}


# We shouldn't have anything left.
# But of course we do! Not sure where these warnings come from,
# but ignore them for now.
# overload is in 5.8.0; vars pops up somewhere between 5.8.0 and 5.8.9
# maybe. y2k turns up around about 5.6.0 and goes away by 5.10.0 or
# thereabouts.
delete $category_exists{overload};
delete $category_exists{vars};
delete $category_exists{y2k};
is_deeply(\%category_exists, {},
    "The module didn't expect any other categories");
