#!/usr/local/bin/perl

package v3::go;

use strict;
use warnings;

use Apache::Constants qw(OK REDIRECT NOT_FOUND);
use Apache::Request;
use v3::template;
use v3::sessions qw (retrieveSession saveSession);
use v3::db;
use Apache::Cookie;
use Data::Dumper;
use File::Basename;
use Apache::Log;

sub handler {
    my $q = Apache::Request->new(shift,  POST_MAX => 100 * 1024 * 1024, DISABLE_UPLOADS => 0 );

    my $method      = $q->method();
    my $uri         = $q->uri();
    my $file        = $uri || "index.html";
    $file           = "$ENV{DOCUMENT_ROOT}$file";
    
    return NOT_FOUND unless -e $file;             # Handle 404

    my $h           = $q->parms(); 
    my $ct          = ($file =~ /.xml$/) ? "application/xml" : "text/html";
    my $hash        = {};
    my $dbh         = &v3::db::getDbh();
    my $session     = {};
    my $headers_in  = $q->headers_in();
    my $headers_out = $q->headers_out();
    my $dir_config  = $q->dir_config();
    
    my ($need_session, $need_login) = ($dir_config->{'NEED_SESSION'},
                                       $dir_config->{'NEED_LOGIN'});

    $q->server()->loglevel(Apache::Log::NOTICE);
    
    if ($need_session) { 
        $session = retrieveSession($dbh, $q);  # session is already baked

        $hash->{_login_name} = $session->{login_name};
        if (0
            || (!$need_login)
            || $hash->{_login_name} =~ /\S/
            || $uri eq "/loginScreen.html"
            || $uri eq "/processLogin.html"
            ) {
            ; # do nothing
        }
        else {
            # login needed
            $dbh->commit;
            $dbh->disconnect;
            return redirectToLoginScreen($q, $uri);
        }
    }

 #    my $resp_headers = $q->headers_out();
    my ($basename, $dir, $type) = fileparse($file, qr/\..*/);

    if ($method ne 'GET' and $method ne 'HEAD') {
        $headers_out->{"expires"} = "-1d";
    }

    
    
    $hash = { headers_out  => $headers_out,
              http_content => undef ,
              method       => $method,
              dir_config   => $dir_config,
              headers_in   => $headers_in,
              request      => $q,
              file         => $file,
              basename     => $basename,
              dir          => $dir,
              type         => $type,
              logger       => $q->log,
    };

    
    my $text = &v3::template::readFile ($q, $file, $hash, $dbh, $session, $h);


    if (defined $hash->{REDIRECT}) {
        $headers_out->{"Location"} = $hash->{REDIRECT};
        $dbh->commit;
        $dbh->disconnect;
        return REDIRECT; # 303?
    }
    elsif (defined $hash->{FILE}) {
        $dbh->commit;
        $dbh->disconnect;
        return handleFile($q, $hash);
    }

    my $status = $hash->{http_status} || OK;

    ###$headers_out->set("expires" => "-1d");
    $q->send_http_header($ct);
    print $text;
    $dbh->commit;
    $dbh->disconnect;
    return $status;
}


sub redirectToLoginScreen {
    my ($q, $uri) = @_;
    my $h = $q->parms;
    my $qs = join("&", map { "$_=$h->{$_}" } (keys %$h)) ;
    $q->headers_out->set("Location" => "/loginScreen.html?__orig=$uri\&$qs");
    return REDIRECT;
}


sub handleFile {
    my ($query, $hash) = @_;
    my $file = $hash->{FILE};
    
    return OK if $file eq "__DONE__";

    my $content_length         = -s $file;
    my ($name, $path, $suffix) = fileparse($file, qr{\..*});
    my $file_name              = "$name$suffix";
    my %mime_types             = ( ".pdf" => "application/pdf",
                                   ".txt" => "text/plain",
                                   ".csv" => "application/vnd-ms-excel",
        );
    my $mime_type              = $mime_types{$suffix};

    if (!$mime_type) {
        print $query->header(-type    => "text/plain",
                             -expires => "-1d",
                             -status  => '500 Unrecognized File Type');
        print "Unrecognized file type\n";
        return 500;
    }

    if (open (FILE, $file)) {
        my ($buffer, $length);
        $query->headers_out->set("expires"             => "-1d");
        $query->headers_out->set("Content-Length"      => $content_length);
        $query->headers_out->set("Content-Disposition" => "inline; filename=\"$file_name\"");
        $query->send_http_header($mime_type);

        while (1) {
            $length = read(FILE, $buffer, 8192);
            if (defined ($length)) {
                if ($length) {
                    print $buffer;
                }
                else {
                    close FILE;
                    return OK;
                }
            }
            else {
                close FILE;
                return OK;
            }
        }
        close FILE;
        return OK;
    }
    else {
        $query->headers_out->set("expires", "-1d");
        $query->send_http_header("text/plain");
        print "ERROR: Cannot open file\n";
        return NOT_FOUND;
    }
}

        
    
    
                  
sub getPage {
    my ($q) = @_;
    my $a =  substr($q->uri(), 1);

    $a =~ s/\&.*//;
    $a =~ s/[^ A-Za-z0-9\/\_\.\-]//g;
    $a =~ s/\.\.//g;

    return $a;
}



1;
