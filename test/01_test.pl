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
my $request = HTTP::Request->new(GET => "$uri_base/test.html");
$request->content('');

# Pass request to the user agent and get a response back
my $response = $user_agent->request($request);

# Check the outcome of the response
ok($response->code == RC_OK, "Can read test.html");

my $expected = qq^<html>
  <head>
  </head>
  <body>
    Test
    <hr>
Test2
<hr>

  </body>
</html>
^;

my $received = $response->content();
$expected =~ s/[\r\n]//g; $expected =~ s/^ +//g; $expected =~ s/ +$//g;
$received =~ s/[\r\n]//g; $received =~ s/^ +//g; $received =~ s/ +$//g;

is($received, $expected, "test.pl looks ok");
