#!/usr/bin/env perl
# Test we can turn on and off various warnings.

use strict;
use warnings;
no warnings qw(uninitialized);

use File::Temp;
use Test::More qw(no_plan);

use_ok('warnings::everywhere');

# All modules will use a common set of methods, defined at the end of
# this test script; pull them in.
my $perl_functions;
{
    local $/ = undef;
    $perl_functions = <DATA>;
}
my @categories_testable = ($perl_functions =~ m{sub \s (\S+) }xgs);

# We need a temporary directory to write this stuff to.
# Let's start with a temporary directory.
# When this goes out of scope it should be deleted.
my $dir = File::Temp->newdir(CLEANUP => 1);
push @INC, $dir->dirname;

# Go through each warning violation in turn, checking that
# we can disable it (a) individually, (b) as part of use warnings,
# and (c) as part of use warnings ('all').
for my $warning (@categories_testable) {
    ok(warnings::everywhere::disable_warning_category($warning),
        "Disable warnings for $warning");
    for my $pragma_suffix ('', q{ ('all')}, qq{ ('$warning')}) {
        # Work out what we're going to call this test package.
        # Use underscores rather than :: to avoid faffing about with
        # creating subdirectories.
        (my $package_suffix = $pragma_suffix) =~ tr/a-z//cd;
        $package_suffix ||= 'standard';
        my $package_name = "test_${warning}_$package_suffix";

        # Build a class that will hopefully run the offending function
        # with warnings suitably enabled.
        my $module_contents = <<BUILD_PACKAGE;
package $package_name;

use warnings$pragma_suffix;

$perl_functions
1;
BUILD_PACKAGE

        # Write this to a file.
        ok(
            open(my $fh_module, '>', $dir->dirname . "/${package_name}.pm"),
            "We can write a new module $package_name to $dir"
        );
        ok(
            (print {$fh_module} $module_contents),
            "We can add our generated module contents"
        );
        ok($fh_module->close, "We can finish writing $package_name to $dir");

        # We can use this module.
        use_ok($package_name);

        # Call the appropriate method.
        my @warning_messages;
        local $SIG{__WARN__} = sub {
            my ($message) = @_;
            push @warning_messages, $message;
        };
        $package_name->$warning();
        local $SIG{__WARN__};

        # We didn't get any warnings
        is_deeply(\@warning_messages, [],
            "No warnings produced for $warning");
    }
}

__DATA__
sub uninitialized {
    my $foo;
    my $bar = $foo . q{ damn, that was an undef wasn't it?};
    return;
}

