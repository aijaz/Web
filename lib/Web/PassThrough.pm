

package v3::PassThrough;

use strict;
use warnings;

sub handle {
    my ($q, $file, $parent_hash, $dbh, $session, $h, $top_hash) = @_;
    my $hash = {};
    
    foreach (keys (%$h)) { $hash->{"__$_"} = $h->{$_} }

    # inherit the settings from the parent hash
    foreach (keys (%$parent_hash)) { $hash->{$_} = $parent_hash->{$_} }
    
    my $file_name = $parent_hash->{basename} || '';
    $hash->{"file_$file_name"} = 1;

    $top_hash->{logger}->notice("This is a notice from Aijaz");

    return $hash;
}

1;
