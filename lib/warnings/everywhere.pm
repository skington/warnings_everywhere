package warnings::everywhere;

use 5.008;
use strict;
use warnings;
no warnings qw(uninitialized);
use Carp;
use File::Spec;

our $VERSION = '0.020';
$VERSION = eval $VERSION;

sub import {
    my $package = shift;
    for my $category (@_) {
        if (!ref($category)) {
            enable_warning_category($category);
        }
    }
}

sub unimport {
    my $package = shift;
    for my $args (@_) {
        if (ref($args)) {
            $package->_check_import_argument($args);
            $package->_thwart_module(%$args);
        } else {
            disable_warning_category($args);
        }
    }
}

sub _check_import_argument {
    my ($package, $argument) = @_;

    return if !ref($argument);
    if (ref($argument) ne 'HASH') {
        croak "Unexpected import argument $argument";
    }
    if (!exists $argument->{warning} || !exists $argument->{thwart_module}) {
        croak "Argument keys must include warning and thwart_module";
    }
    _check_warning_category($argument->{warning}) or die;
}

=head1 NAME

warnings::everywhere - a way of ensuring consistent global warning settings

=head1 VERSION

This is version 0.020.

=head1 SYNOPSIS

 # Turn off run-time warnings
 use strict;
 use warnings;
 no warnings::anywhere qw(uninitialized);
 
 use Module::That::Spits::Out::Warnings;
 use Other::Unnecessarily::Chatty::Module;

 use warnings::everywhere qw(uninitialized);
 # Write your own bondage-and-discipline code that really, really
 # cares about the difference between undef and the empty string
 
 # Stop "helpful" modules from turning compile-time warnings back on again
 use strict;
 use warnings;
 no warnings::anywhere {
     warning       => 'experimental::smartmatch',
     thwart_module => [qw(Moose Moo Dancer Dancer2)],
 };
 use Module::That::Might::Pull::In::Moose::Or::Moo::Or::Who::Knows::What;
 
 given (shift @ARGV) {
     ...
     default {
         print STDERR "# I'll fix it in a moment, OK?\n";
     }
 }

=head1 DESCRIPTION

Warnings are great - in your own code. Tools like prove, and libraries
like Moose and Modern::Perl, turn them on for you so you can spot things
like ambiguous syntax, variables you only used once, deprecated syntax
and other useful things.

By default C<use warnings> turns on all warnings, including some that
you might not care about, like uninitialised variables. You could explicitly
say

 use warnings;
 no warnings qw(uninitialized);

or you could use a module like C<common::sense> which disables some warnings
and makes others fatal, or you could roll your own system. Either way,
for your own code, there are plenty of ways around unwanted warnings.

Not so for other code, though.

The test suite at $WORK produces a large number of 'use of uninitialized
variable' warnings from (at the last count) four separate modules. Some of
them are because warnings got switched on for that module,
even though the module itself didn't say anything about warnings
(probably because the test suite was run with prove).
Others are there because the module explicitly said C<use warnings>, and
then proceeded to blithely throw around variables without checking whether
they were defined first.

Either way, this isn't my code, and it's not something I'm going to fix.
These warnings are just spam.

Similarly, if you disable e.g. experimental::smartmatch because you know that
you're using smartmatch, and you're not going to be using a version of
Perl that has a version of smartmatch that behaves differently, you might
get those warnings enabled back again by a module such as Moose or Dancer
which turns all warnings on.

This is where warnings::everywhere comes in.

=head2 Usage

=head3 Run-time warnings

At its simplest, say

 use warnings::everywhere qw(all);

and all modules imported from there onwards will have all warnings switched
on. Modules imported previously will be unaffected. You can turn specific
warnings off by saying e.g.

 no warnings::everywhere qw(uninitialized);

or, depending on how frustrated and/or grammatically-sensitive you happen
to be feeling,

 no warnings::anywhere qw(uninitialized);

or

 no goddamn::warnings::anywhere qw(uninitialized);

Parameters are the same as C<use warnings>: a list of categories
as per L<perllexwarn>, where C<all> means all warnings.

=head3 Compile-time warnings

This won't work for some (all?) compile-time warnings that are not just
enabled for the module in question, but are injected back into your package.
Moose, Moo, Dancer and Dancer2 all do this at the time of writing, by saying
C<warnings->import> in their import method, thus injecting all warnings into
I<your> package.

To stop such code from turning back on warnings that you thought you'd
disabled, say e.g.

 no warnings::anywhere {
     warning       => 'experimental::smartmatch',
     thwart_module => [qw(Moose)],
 };

B<Warning>: warnings::everywhere disables these warnings by what is basically
a source filter, so use with caution. If you can find an approved way of
preventing modules such as Moose from doing this, do that rather than
messing about with the module's source code!

=head2 Limitations

warnings::everywhere works by fiddling with the contents of the global hashes
%warnings::Bits and %warnings::DeadBits. As such, there are limitations on
what it can and cannot do:

=over

=item It cannot affect modules that are already loaded.

If you say

 use Chatty::Module;
 no warnings::anywhere qw(uninitialized);

that's no good - Chatty::Module has already called C<use warnings> and
uninitialized variables was in the list of enabled warnings at that point,
so it will still spam you.

Similarly, this is no help:

 use Module::That::Uses::Chatty::Module;
 no warnings::anywhere qw(uninitialized);
 use Chatty::Module;

Chatty::Module was pulled in by that other module already by the time
perl gets to your use statement, so it's ignored.

=item It's vulnerable to anything that sets $^W

Any code that sets the global variable $^W, rather than saying C<use warnings>
or C<warnings->import>, will turn on all warnings everywhere, bypassing the
changes warnings::everywhere makes. This also includes any code that sets -w
via the shebang.

Any change to warnings by any of the warnings::anywhere code will turn off $^W
again, whether it's a use statement or an explicit call to
L<disable_warning_category> or similar.

Any module that claims to enable warnings for you is potentially suspect
- Moose is fine, but Dancer sets $^W to 1 as soon as it loads, even if your
configuration subsequently disables import_warnings.

=item It cannot make all modules use warnings

All it does is fiddle with the exact behaviour of C<use warnings>,
so a module that doesn't say C<use warnings>, or import a module that
injects warnings like Moose, will be unaffected.

=item It's not lexical

While it I<looks> like a pragma, it's not - it fiddles with global settings,
after all. So you can't say

 {
     no warnings::anywhere qw(uninitialized);
     Chatty::Module->do_things;
 }
 Unchatty::Module->do_stuff(undef);

and expect to get a warning from the last line. That warning's been
turned off for good.

=item Its method of disabling compile-time warnings is frankly iffy

The best I can say about its method of messing with the source code of
imported modules is that at least its modifications shouldn't stack with
other source filters, so the degree of weirdness and potential insanity
should be reduced to a manageable level.

=back

=head1 SUBROUTINES

warnings::anywhere provides the following functions, mostly for diagnostic
use. They are not exported or exportable.

=over

=item categories_enabled

 Out: @categories

Returns a sorted list of warning categories enabled globally. Before you've
fiddled with anything, this will be the list of warning categories from
L<perllexwarn>, minus C<all> which isn't a category itself.

Fatal warnings are ignored for the purpose of this function.

=cut

sub categories_enabled {
    my @categories;
    for my $category (_warning_categories()) {
        push @categories, $category
            if _is_bit_set($warnings::Bits{$category},
            $warnings::Offsets{$category});
    }
    return @categories;
}

=item categories_disabled

 Out: @categories

Returns a sorted list of warning categories disabled globally. Before
you've fiddled with anything, this will be the empty list.

Fatal warnings are ignored for the purpose of this function.

=cut

sub categories_disabled {
    my @categories;
    for my $category (_warning_categories()) {
        push @categories, $category
            if !_is_bit_set($warnings::Bits{$category},
            $warnings::Offsets{$category});
    }
    return @categories;
}

sub _warning_categories {
    my @categories = sort grep { $_ ne 'all' } keys %warnings::Offsets;
    return @categories;
}

=item enable_warning_category

 In: $category

Supplied with a valid warning category, enables it for all future
uses of C<use warnings>.

=cut

sub enable_warning_category {
    my ($category) = @_;

    _check_warning_category($category) or return;
    _set_category_mask($category, 1);
    return 1;
}

sub _set_category_mask {
    my ($category, $bit_value) = @_;

    # Set or unset the specific category bit value (e.g. if
    # someone says use warnings qw(uninitialized) or
    # no warnings qw(uninitialized)).
    _set_bit_mask(\($warnings::Bits{$category}),
        $warnings::Offsets{$category}, $bit_value);

    # Compute what the bitmask for all should be.
    $warnings::Bits{all} = _bitmask_categories_enabled();

    # If we've enabled all categories, we should probably set
    # the all bit as well, just for tidiness.
    if ($bit_value) {
        if (!categories_disabled()) {
            _set_bit_mask(\$warnings::Bits{all}, $warnings::Offsets{all}, 1);
        }
    }
    ### TODO: fatal warnings

    # Finally, if someone specified the -w flag (which turns on all
    # warnings, globally), turn it off.
    $^W = 0;
}

=item disable_warning_category

 In: $category

Supplied with a valid warning category, disables it for future
uses of C<use warnings> - even calls to explicitly enable it.

=cut

sub disable_warning_category {
    my ($category) = @_;

    _check_warning_category($category) or return;
    _set_category_mask($category, 0);
    return 1;
}

sub _bitmask_categories_enabled {
    my $mask;
    for my $category_enabled (categories_enabled()) {
        _set_bit_mask(\$mask, $warnings::Offsets{$category_enabled}, 1)
    }
    return $mask;
}

sub _set_bit_mask {
    my ($mask_ref, $bit_num, $bit_value) = @_;

    # First get the correct byte from the mask, then set that byte's
    # bit accordingly.
    # We have to do it this way as warning masks are hundreds of bits wide,
    # which neither a 32- nor a 64-bit Perl can deal with natively.
    # The mask might not be long enough, so pad it with null bytes if
    # we need to first.
    my $byte_num = int($bit_num / 8);
    while (length($$mask_ref) < $byte_num) {
        $$mask_ref .= "\x0";
    }
    my $byte_value = substr($$mask_ref, $byte_num, 1);
    vec($byte_value, $bit_num % 8, 1) = $bit_value;
    substr($$mask_ref, $byte_num, 1) = $byte_value;
    return $$mask_ref;
}

sub _is_bit_set {
    my ($mask, $bit_num) = @_;

    my $smallest_bit_num = $bit_num % 8;
    return vec($mask, int($bit_num / 8), 8) & (1 << $smallest_bit_num);
}

sub _dump_mask {
    my ($mask) = @_;

    my $output;
    for my $byte_num (reverse 0..15) {
        $output .= sprintf('%08b', vec($mask, $byte_num, 8));
        $output .= ($byte_num % 4 == 0 ? "\n" : '|');
    }
    return $output;
}

sub _check_warning_category {
    my ($category) = @_;

    return if $category eq 'all';
    if (!exists $warnings::Offsets{$category}) {
        carp "Unrecognised warning category $category";
        return;
    }
    return 1;
}

sub _thwart_module {
    my ($package, %args) = @_;

    # There are two ways of thwarting modules: the usual Perlish way,
    # and one special mode for Moose, which generates its own import
    # sub which can't be wrapped.
    my $module = $args{thwart_module};
    my $mode = 'append_sub';
    if ($module eq 'Moose') {
        $module = 'Moose::Exporter';
        $mode   = 'append_statement';
    }
    my $filename = $module;
    $filename =~ s{::}{/}g;
    $filename .= '.pm';
    unshift @INC, sub {
        my ($this_coderef, $use_filename) = @_;
        return if $use_filename ne $filename;

        # Find the source of the module we're looking for.
        # This will fail if the module is itself being loaded by a
        # coderef in @INC, say, but should work for the vast, vast
        # majority of cases.
        my $source_fh = $package->_find_module_source($use_filename)
            or do {
            croak "You asked me to thwart $args{thwart_module}"
                . " but I can't find $use_filename anywhere in @INC";
            };
        my $source;
        {
            local $/;
            $source = <$source_fh>;
        }

        # Work out what we're going to inject into this source code.
        my @warnings
            = ref($args{warning} eq 'ARRAY')
            ? @{ $args{warning} }
            : $args{warning};
        my $source_code_unimport;
        for my $warning (@warnings) {
            $source_code_unimport .= qq{warnings->unimport("$warning");\n};
        }
        my $injection_warning_start = "### Code injected by $package";
        my $injection_warning_end   = "### End of code injected by $package";

        # We might be adding an extra import sub.
        if ($mode eq 'append_sub') {
            my $extra_code = <<EXTRACODE;
$injection_warning_start
my \$__warnings_everywhere_orig_import = \\\&${module}::import;
{
    no warnings 'redefine';
    *${module}::import = sub {
        \$__warnings_everywhere_orig_import->(\@_);
        $source_code_unimport
    }
}
$injection_warning_end
1;
EXTRACODE

            # This wants to go either at the end, or before __END__ or
            # __DATA__
            $source =~ s/^ (__ (?: END|DATA ) __) $/$extra_code$1/xsm
                or $source .= $extra_code;

        # Or we might be adding our import statements immediately
        # after the call to import.
        } elsif ($mode eq 'append_statement') {
            $source =~ s{
                ( warnings->import; \n )
            }{
$1
$injection_warning_start
$source_code_unimport
$injection_warning_end
            }x;
        }

        # Right, return this modified source code.
        open (my $fh_source, '<', \$source);
        return $fh_source;
    };
}

sub _find_module_source {
    my ($package, $use_filename) = @_;

    for my $dir (grep { !ref($_) } @INC) {
        my $full_path = File::Spec->catfile($dir, $use_filename);
        if (-e $full_path) {
            open (my $fh, '<', $full_path);
            return $fh;
        }
    }
    return;
}


=back

=head1 TO DO

Support for fatal warnings, possibly.
It's possible it doesn't behave correctly when passed 'all'.

=head1 DIAGNOSTICS

=over

=item Unrecognised warning category $category

Your version of Perl doesn't recognise the warning category $category.
Either you're using a different version of Perl than you thought, or a
third-party module that defined that warning isn't loaded yet.

=back

=head1 SEE ALSO

L<common::sense>

=head1 AUTHOR

Sam Kington <skington@cpan.org>

The source code for this module is hosted on GitHub
L<https://github.com/skington/warnings_everywhere> - this is probably the
best place to look for suggestions and feedback.

=head1 COPYRIGHT

Copyright (c) 2013 Sam Kington.

=head1 LICENSE

This library is free software and may be distributed under the same terms as
perl itself.

=cut

1;
