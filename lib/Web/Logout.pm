
package Logout;

use strict;
use warnings;
use Data::Dumper;
use db;
 
sub handle {
    my ($q, $parentHash, $dbh, $session) = @_;
    my $hash = {};
    my $h = $q->parms();



    # delete cookie from the database
    &db::deleteCookie($dbh, $session->{cookie_string});
    
    $hash->{REDIRECT} = "/index.html";
    
    return $hash;
}


1;
