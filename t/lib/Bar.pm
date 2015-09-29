package Bar;

use warnings;

sub import { strict->import; warnings->import; }

1;
__DATA__
Bet you weren't expecting something like this, huh?

__END__
=head1 NAME

Bar - a random toy class that imports warnings via inheriting from Foo

=head1 SYNOPSIS

What do you care?

=cut
