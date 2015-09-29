package Foo;

=head1 NAME

Foo -  a toy class that enables warnings in the calling class

=cut

sub import {
    warnings->import;
}

1;
