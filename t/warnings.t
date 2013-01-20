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
my (%perl_function, $current_function);
line:
while (<DATA>) {
    next line if !/\S/;
    /^ sub \s+ (\S+) \s+ { /x and do {
        $current_function = $1;
    };
    $perl_function{$current_function} .= $_;
}
my @categories_testable = sort keys %perl_function;
if ($ENV{CATEGORY}) {
    @categories_testable = grep { /$ENV{CATEGORY}/ } @categories_testable;
}

# We need a temporary directory to write this stuff to.
# When this goes out of scope it should be deleted.
my $dir = File::Temp->newdir(CLEANUP => 1);
push @INC, $dir->dirname;

# Go through each warning violation in turn, checking that
# we can disable it (a) individually, (b) as part of use warnings,
# and (c) as part of use warnings ('all').
for my $warning (@categories_testable) {
    ok(warnings::everywhere::disable_warning_category($warning),
        "Disable warnings for $warning")
        unless $ENV{FAIL};
    for my $pragma_suffix ('', q{ ('all')}, qq{ ('$warning')}) {
        _test_package(warning => $warning, pragma_suffix => $pragma_suffix);
    }
    ok(warnings::everywhere::enable_warning_category($warning),
        "Enable warnings again for $warning");
}

sub _test_package {
    my (%args) = @_;

    # Work out what we're going to call this test package.
    # Use underscores rather than :: to avoid faffing about with
    # creating subdirectories.
    (my $package_suffix = $args{pragma_suffix}) =~ tr/a-z//cd;
    $package_suffix ||= 'standard';
    my $package_name = "test_$args{warning}_$package_suffix";

    # Build a class that will hopefully run the offending function
    # with warnings suitably enabled.
    my $module_contents = <<BUILD_PACKAGE;
package $package_name;

use warnings$args{pragma_suffix};

$perl_function{$args{warning}}
1;
BUILD_PACKAGE

    # Write this to a file.
    ok(open(my $fh_module, '>', $dir->dirname . "/${package_name}.pm"),
        "We can write a new module $package_name to $dir");
    ok(
        (print {$fh_module} $module_contents),
        "We can add our generated module contents"
    );
    ok($fh_module->close, "We can finish writing $package_name to $dir");

    # We can use this module.
    my @warning_messages;
    local $SIG{__WARN__} = sub {
        my ($message) = @_;
        push @warning_messages, $message;
    };
    use_ok($package_name);

    # Call the appropriate method.
    my $method = $args{warning};
    $package_name->$method();
    undef $SIG{__WARN__};

    # We didn't get any warnings
    is_deeply(\@warning_messages, [],
        "No warnings produced for $args{warning}, $args{pragma_suffix}");
}

__DATA__

sub ambiguous {
    sub foo { 1 };
    my $foo = -foo;
}

sub bareword {
    my $foo = Foo::;
}

sub closed {
    open(my $fh, '<', $0);
    close($fh);
    flock($fh, 0);
}

sub closure {
    my $foo;
    sub sort_of_closure {
        my $bar = $foo;
    }
}

# WONTFIX: debugging. Looks like scary internal magic here.

sub deprecated {
    my @foo;
    if (defined @foo) {
        1;
    }
}

sub digit {
    my $hex = hex('a curse upon both houses!');
}

sub exec {
    exec("hoo____ray! this should never, never, ever work");
}

sub exiting {
    sub other_sub {
        last loop;
    }
    loop:
    for (1..5) {
        other_sub();
    }
}

### FIXME: glob? Looks hard to trigger portably

# WONTFIX: inplace - mostly for one-liners, which this pragma isn't for.

# WONTFIX: internal - can't reproduce without serious XS voodoo.

sub io {
    require DirHandle;
    my $dir_handle = DirHandle->new('.');
    $dir_handle->close;
    closedir($dir_handle);
}

sub illegalproto {
    sub foo (this is not a valid prototype) {
        return;
    }
}

### TODO: imprecision; can't find it in perldiag

sub layer {
    open(my $fh, '<:unix and nothing else', $0);
}

# WONTFIX: malloc - hell no.

sub misc {
    my $wannabe_object = { stuff => 'awesome' };
    bless $wannabe_object => '';
}

sub newline {
    open(my $fh, "You can't have\nnewlines\nin file names\nThat's wrong\n\n");
}

# WONTFIX: non_unicode - can't easily reproduce at the moment

# WONTFIX: nonchar - nor this one

sub numeric {
    my $foo = "he-man" ** "greyskull";
}

### FIXME: can't seem to reproduce a once warning

### FIXME: overflow is tricky to trigger on a 64-bit system

sub pack {
    sub ultimate_answer {
        return 6 * 9;
    }
    my $foo = pack('p', ultimate_answer());
}

sub parenthesis {
    my $foo, $bar = @_;
}

sub pipe {
    open (my $fh, "|magritte|")
}

sub portable {
    ### TODO: does this still work on 32-bit systems?
    my $large_number = eval('0b' . (1 x 40));
}

sub precedence {
    my ($foo, $bar) = (0, 0);
    if ($foo & $bar == 0) {
        
    }
}

sub printf {
    my $foo = sprintf('%zebra', 'stripes');
}

sub prototype {
    do_stuff(qw(foo bar baz));
    sub do_stuff ($) {
        return 'meh';
    }
}

sub qw {
    my @list = qw(haven't, really, understood, the, point, of, this);
}

sub recursion {
    # Global variable so we don't get a "won't stay shared" closure warning.
    $times::called = 0;
    sub try_try_try_again {
        if ($times::called++ < 100) {
            return try_try_try_again();
        }
        return;
    }
    try_try_try_again();
}

sub redefine {
    sub bernie_taupin_lyric { 'If I were a sculptor' }
    sub bernie_taupin_lyric { 'But then again no'    }
}

sub regexp {
    my $regexp = qr/[:alpha:]/;
}

# WONTFIX: reserved; difficult to test under use strict, and it's a good one.

### TODO: find a way to trigger the semicolon warning.

### TODO: deal with severe somehow?

### TODO: can't seem to disable signal?

sub substr {
    my $parrot = { squawk => 'Polly wants a cracker' };
    substr($parrot, 0, 1) = 'parakeet';
}

# WONTFIX: surrogate; nasty UTF16 stuff I don't want to get involved with.

sub syntax {
    my $foo = 'foo';
    $foo =~ s/[.][.]/\1\2/;
}

# WONTFIX: taint; too much trouble to enable taints and pass them to system
# calls.

# WONTFIX: threads; tricky to emulate, and why the hell would you ever
# make life more difficult for yourself when programming threads?

sub uninitialized {
    my $foo;
    my $bar = $foo . q{ damn, that was an undef wasn't it?};
    return;
}

sub unopened {
    my $fh = 'foo';
    binmode($fh);
}

sub unpack {
    # Straight out of the man page!
    my $foo = unpack("H", "\x{2a1}");
}

### FIXME: untie, if anyone cares?

# WONTFIX: utf8; problematic on older perls.

sub void {
    my $foo = sort qw(foo bar baz);
}
