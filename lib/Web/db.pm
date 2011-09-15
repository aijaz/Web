package Web::db;

use DBI;
use Data::Dumper;
use Date::Manip;

sub new {
    my $arg = shift;
    my $class = (ref $arg) || $arg;
    my $pid = $$;
    $n++;
    my $unique_id = join("_", time, $pid, $n);

    my $self = {
        name         => '',
        rc           => '',                       # exit code
        status       => 'Waiting',
        unique_id    => $unique_id,
        
        params       => '',
        
    };

    my %args = @_;

    # set up any other parameters that the caller may have passed in 
    #
    foreach my $key (keys %args) {
        $self->{$key} = $args{$key};
    }

    croak "No Job name specified" unless $self->{name};

    bless $self, $class;
    return $self;
}

sub getResultSet {
    my ($st, $fn, @parms) = @_;
    my $result = $st->fetchall_arrayref({});
    my @oe = qw (even odd);
    my $oe = 0;
    my $item;
    my $empty = 1;
    my $itemn = 0;
    foreach $item (@$result) {
        $item->{oe}      = $oe;
        $item->{oddeven} = $oe[$oe];
        $oe              = $oe ^ 1;
        $empty           = 0;
        $itemn++;
        if ($fn) { $fn->($item, @parms) }
        $item->{itemn}   = $itemn;
    }
    return ($result, $empty);
}


sub getDbh {
    my $dbname    = 'pcp';
    my $user      = 'pcp';
    my $pass      = 'pcp';

    my $dbh = DBI->connect("dbi:Pg:dbname=$dbname", $user, $pass,
        {
            PrintError => 1, # warn() on errors
            RaiseError => 1, # die on error
            AutoCommit => 0, # commit executes immediately
        }) or die DBI::errstr;

    return $dbh;
}



sub deleteCookie {
    my ($dbh, $cookie_from_browser) = @_;
    $dbh->do("delete from cookies.cookie where cookie_string='$cookie_from_browser'");
}

sub deleteCookieForLogin {
    my ($dbh, $login) = @_;
    $dbh->do("delete from cookies.cookie where fk_login_name='$login'");
}

sub getCookie {
    my ($dbh, $cookie_from_browser) = @_;

    my $st = $dbh->prepare("select fk_login_name from cookies.cookie where cookie_string=?");
    $st->execute($cookie_from_browser);
    my ($login_name) = $st->fetchrow_array;
    $st->finish;
    $login_name = '' unless $login_name;
    #return ({ cookie_string => $cookie_from_browser }) unless $login_name;
    return { cookie_string => $cookie_from_browser, login_name => $login_name};
}

sub saveCookie {
    my ($dbh, $hash) = @_;
    
    &deleteCookieForLogin($dbh, $hash->{login_name});
    $dbh->do("insert into cookies.cookie(cookie_string, fk_login_name) values('$hash->{cookie_string}', '$hash->{login_name}')");
        
}


1;

