#!/usr/bin/env perl
# Stop Moose from re-enabling experimental warnings on us.

use strict;
use warnings;
no warnings 'uninitialized';
use English qw(-no_match_vars);
use File::Spec;
use IPC::Open3;
use Symbol 'gensym';
use Test::More;

use lib::abs 'lib';
use warnings::everywhere::utils qw(temp_dir);

# Don't even try this if we don't have the experimental warning category.
if (!$PERL_VERSION || $PERL_VERSION lt v5.18.0) {
    plan skip_all => 'No experimental::smartmatch warning';
}
plan 'no_plan';

# Right, generate a place to put code.
my ($temp_dir, $temp_dir_object) = temp_dir();
push @INC, $temp_dir;

# Try each module in turn. Dancer2 will get annoyed if it tries to load
# a config file from /loader/0xdeadbeef/blah which is where it appears to
# have been loaded if we mess with it via an @INC coderef, so claim that
# it has a perfectly reasonable config directory instead.
$ENV{DANCER_CONFDIR} = $temp_dir;
module:
for my $module (qw(Moo Dancer Dancer2)) {
    # Make sure we have this module installed.
    eval "use $module qw(); 1" or do {
        Test::More->builder->skip("$module not installed");
        next module;
    };

    # OK, generate a test class.
    my $class = 'thwart_' . $module;
    my $file = File::Spec->catfile($temp_dir, "$class.pm");
    ok(
        open(my $fh, '>', $file),
        "We can write $class.pm to $file"
    );
    my $inc_list = join("\n", @INC);
    ok(do { print {$fh} <<MODULE_SOURCE }, "We can write ${class}'s source");
#!/usr/bin/env perl
package $class;

use lib qw(
    $inc_list
);
use feature 'switch';
no warnings::anywhere {
    warning       => 'experimental::smartmatch',
    thwart_module => '$module',
}, 'uninitialized';
use $module;

my \$foo;
given (\$foo) {
    when (['h', '--h', 'help', '--help']) {
        die "No idea, haven't written it yet\\n";
    }
    when ('cunning') {
        print STDERR "\$_ sounds like a plan\\n";
    }
}

print STDERR "# $file was compiled successfully\n";

# Should generate uselessuse of constant in void context warning,
# from use warnings.
my \$bar => 42;

# Should trigger "Can't use string as a SCALAR ref" warning from strict.
my \$bar_ref = 'bar';
\$\$bar_ref = 42;

1;
MODULE_SOURCE
    ok($fh->close, "We can close the file for $class");

    # It shouldn't produce any warnings.
    my ($stdin, $stdout, $stderr);
    $stderr = Symbol::gensym;
    my $pid = IPC::Open3::open3($stdin, $stdout, $stderr,
        'perl', $file);
    waitpid($pid, 0);
    my $stderr_output;
    {
        local $/;
        $stderr_output = <$stderr>;
    }
    unlike(
        $stderr_output,
        qr/is \s experimental/x,
        "No experimental warnings for $module"
    );
    like(
        $stderr_output,
        qr/^ \# \s $file \s was \s compiled \s successfully $/xsm,
        "$module was loaded"
    );
    like($stderr_output, qr/^ Useless [^\n]+ void \s context [^\n]+ $/xsm,
        "$module imported warnings");
    like(
        $stderr_output,
        qr/^ Can't \s use \s string [^\n]+ SCALAR \s ref [^\n]+ $/xsm,
        "$module imported strict"
    );
}
