package warnings::everywhere;

use 5.008;
use strict;
use warnings;
no warnings qw(uninitialized);

our $VERSION = "0.001";
$VERSION = eval $VERSION;

use Carp;

=head1 NAME

warnings::everywhere - a way of ensuring consistent global warning settings

=head1 SYNOPSIS

 no warnings::anywhere qw(uninitialized);
 use Module::That::Spits::Out::Warnings;
 use Other::Unnecessarily::Chatty::Module;
 use warnings::everywhere qw(uninitialized);
 # Write your own bondage-and-discipline code that really, really
 # cares about the difference between undef and the empty string

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

This is where warnings::everywhere comes in.

=head2 Usage

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

=item It cannot make all modules use warnings

All it does is fiddle with the exact behaviour of C<use warnings>,
so a module that doesn't say C<use warnings>, or import a module that
injects warnings like Moose, will be unaffected.

=back

=head2 Functions

warnings::anywhere provides the following functions, mostly for diagnostic
use. They are not exported or exportable.

=over

=item categories_enabled

 Out: @categories

Returns a sorted list of warning categories enabled globally. Before you've
fiddled with anything, this will be the list of warning categories from
L<perllexwarn>, minus C<all> which isn't a category itself.

Fatal warnings are ignored for the purpose of this function.
FIXME: recognise fatal warnings.

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
FIXME:: recognise fatal warnings.

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

TODO: what do we do about all?

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

    return vec($mask, int($bit_num / 8), 8) & (1 << ($bit_num % 8));
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

=back

=cut

1;
