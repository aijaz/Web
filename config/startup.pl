#!/usr/bin/perl

use strict;
use warnings;

use Apache::DBI;
use Apache::Log;
use DBI ();
use Carp ();
use Data::Dumper;
$Data::Dumper::Indent = 1;

use Date::Manip qw (UnixDate ParseDate);

unshift(@INC, '/Users/aijaz/CocoaApps/Web/lib');

$ENV{MOD_PERL} or die "not running under mod_perl!";

# # # Load Perl modules of your choice here
# # # This code is interpreted *once* when the server starts
$SIG{__WARN__} = \&Carp::cluck;

my $dbname = 'web';
my $user   = 'web';
my $pass   = 'web';


Apache::DBI->connect_on_init("dbi:Pg:dbname=$dbname", $user, $pass,
                             {
                                 PrintError => 1, # warn() on errors
                                 RaiseError => 0, # don't die on error
                                 AutoCommit => 0, # commit executes immediately
                             }
    );


1;
