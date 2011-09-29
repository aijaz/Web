
package Login;

use strict;
use warnings;
use Data::Dumper;
use db;
 
sub handle {
    my ($q, $parentHash, $dbh, $session) = @_;
    my $hash = {};
    my $h = $q->parms();

    
    foreach (keys (%$h))          { $hash->{$_}    = $h->{$_}          }
    foreach (keys (%$parentHash)) { $hash->{$_}    = $parentHash->{$_} }
    foreach (keys (%$session))    { $hash->{"_$_"} = $session->{$_}    }

    # make sure login is correct
    my ($person_id, $is_admin) = &db::checkLogin($dbh, $hash->{login}, $hash->{password});

    if ($person_id) {
        my $cookie_string = $session->{cookie_string};

        &db::deleteCookieForLogin($dbh, $hash->{login});
        print STDERR "cookie string is $cookie_string login in $hash->{login} and is_admin is $is_admin\n";
        &db::createCookie($dbh, {cookie_string => $cookie_string,
                                 login => $hash->{login},
                                 is_admin => $is_admin,
                          });

        
        $hash->{REDIRECT} = $h->{__orig};
        
    }
    else {
        $hash->{message} = "Login Failed.";
    }

    
    return $hash;
}


1;
