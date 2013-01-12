package warnings::everywhere;

use strict;
use warnings;
no warnings qw(uninitialized);

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
them are because warnings got switched on - somehow - for that module,
even though the module itself didn't say anything about warnings.
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
        ### TODO: check better
        push @categories, $category
            if $warnings::Bits{$category} ne $warnings::NONE;
    }
    return @categories;
}

sub _warning_categories {
    my @categories = sort grep { $_ ne 'all' } keys %warnings::Offsets;
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
        ### TODO: check better
        push @categories, $category
            if $warnings::Bits{$category} eq $warnings::NONE;
    }
    return @categories;
}

=back

=back

=cut

1;
