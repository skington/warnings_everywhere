package warnings::everywhere::utils;

use strict;
use warnings;
no warnings 'uninitialized';

use parent 'Exporter';
our @EXPORT_OK = qw(temp_dir);

sub temp_dir {
    my ($dir, $dir_object);

    if (File::Temp->can('newdir')) {
        $dir_object = File::Temp->newdir(CLEANUP => 1);
        $dir = $dir_object->dirname;
    } else {
        $dir = File::Spec->tmpdir();
    }

    return $dir, $dir_object;
}

1;