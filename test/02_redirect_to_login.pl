#!/usr/local/bin/perl

use strict;
use warnings;

use Test::More qw(no_plan);

use LWP::UserAgent;
use HTTP::Status;
use HTTP::Request::Common;
use Data::Dumper;
use DateTime;
use File::Basename;

my $user_agent = LWP::UserAgent->new;
my $uri_base = "http://127.0.0.1";

# Create a request
my $request = HTTP::Request->new(GET => "$uri_base/admin/atest.html");
$request->content('');

# Pass request to the user agent and get a response back
my $response = $user_agent->request($request);

# Check the outcome of the response
ok($response->code == RC_OK, "Can request atest.html");

my $received = $response->content();
is($received =~ /iLoginForm/, 1, "got login form");
