package v3::sessions;

use Exporter();
@ISA = qw(Exporter);
@EXPORT = qw(retrieveSession deleteSession);

use Apache::Cookie;
use Data::Dumper;
use v3::db;


my $cookie_exp = '1 hr';
my $cookie_name = 'ENoorCmsWEB';

sub getCookie {
    my ($q, $name) = @_;

    my %cookie_jar = Apache::Cookie->new($q)->parse;
    if ($cookie_jar{$name}) {
        return $cookie_jar{$name}->value;
    }
    return undef;
}


sub deleteSession {
    my ($q, $dbh) = @_;

    my $cookies_from_browser = getCookie($q, $cookie_name);
    if ($cookies_from_browser) {
        &v3::db::deleteCookie($dbh, $cookie_from_browser);
    }
}

sub writeSession {
}


sub retrieveSession {
    my ($dbh, $q) = @_;

    my $cookie_from_browser = getCookie($q, $cookie_name);
    unless ($cookie_from_browser) {
        # create a new cookie and save it to disk
        my $cookie_string = createCookieString(); 
        my $cookie        = Apache::Cookie->new($q,
                                                -name => $cookie_name,
                                                -value => $cookie_string,
                                                -expires => "+1d", );
        $cookie->bake();   # bake it right here
        return ({cookie_string => $cookie_string, new => 1, login_name => '', cookie => $cookie, is_admin => 0});
    }
    
    # retrieved from browser (still valid)
    my $cookie = Apache::Cookie->new($q,
                                     -name => $cookie_name,
                                     -value => $cookie_from_browser,
                                     -expires => "+1d", );
    $cookie->bake();   # bake it right here

    # now read value from disk
    my $cookie_hash = &v3::db::getCookie($dbh, $cookie_from_browser);
    $cookie_hash->{cookie} = $cookie;
    return $cookie_hash;
}

sub createCookieString {
    my @chars = ('a'..'z','0'..'9','A'..'Z');
    my $num_chars = 62;
    my $cookie_length=32;
    my @cookie = ();

    while ($cookie_length) {
        push (@cookie, $chars[rand $num_chars]);
        $cookie_length--;
    }
    return join('', @cookie);
}



1;
