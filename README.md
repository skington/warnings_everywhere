warnings_everywhere
===================

Perl module warnings::everywhere (and related warnings::anywhere)

Lets you do things like this:

 no warnings::anywhere qw(uninitialized);
 use Module::That::Spits::Out::Warnings;
 use Other::Unnecessarily::Chatty::Module;
 use warnings::everywhere qw(uninitialized);
 # Write your own bondage-and-discipline code that really, really
 # cares about the difference between undef and the empty string

or

 use warnings::everywhere qw(all);
 no warnings::everywhere qw(uninitialized);
 no warnings::anywhere qw(uninitialized);
 no goddamn::warnings::anywhere qw(uninitialized);

TODO:

Port over all the code.
Write more tests.
Check it works with fatal warnings.
Module aliases.
CPAN stuff like licences, version numbers etc.
Work out where the overload warning comes from.
Test on 5.8.0, 5.11.0, 5.13.0 and boundary perls.