package Web::REST;

use strict;
use warnings;
use HTTP::Status;
use Data::Dumper;

BEGIN {
    use vars qw($VERSION);
    $VERSION     = '1.30';
}

sub methodNotAllowed {
    my ($hash, $allow) = @_;

    $hash->{response_headers}->header("Allow",  $allow);
    $hash->{http_status} = RC_METHOD_NOT_ALLOWED;
    $hash->{http_content} = '';

}

# 'correct' GET functionality.
# needs a reference to a check_existence and get_modified_tags() and a get_content() function
sub GET {
    my ($q, $parent_hash, $h, $hash, $resource_functions) = @_;

    my $exists                 = $resource_functions->{check_existence}->($q, $parent_hash, $h, $hash);

    if (!$exists) {
        $parent_hash->{http_status} = RC_NOT_FOUND;
        $parent_hash->{content} = "404 - Not Found";
        return;
    }
    
    my ($last_modified, $etag) = $resource_functions->{get_modified_tags}->($q, $parent_hash, $h, $hash);
    my $if_modified_since      = $parent_hash->{request_headers}->if_modified_since;
    my $if_none_match          = $parent_hash->{request_headers}->header('if-none-match');

    my $uri = $parent_hash->{request}->uri;
    if ($uri =~ /rest/) {
        
        if ( 
            ($if_modified_since && $last_modified <= $if_modified_since)
            ||
            ($if_none_match     && $etag eq $if_none_match)
            ) {
            # don't need to send anything back;
            $parent_hash->{http_content} = "";
            $parent_hash->{http_status} = RC_NOT_MODIFIED;
            $parent_hash->{response_headers}->last_modified($last_modified);
            $parent_hash->{response_headers}->header('ETag', $etag);
            $parent_hash->{response_headers}->header('Cache-Control', 'Public');
            return;
        }
        
        # get the contents and populate the hash as needed
        $resource_functions->{get_content}->($q, $parent_hash, $h, $hash);
        $parent_hash->{http_status} = RC_OK;
        $parent_hash->{response_headers}->last_modified($last_modified);
        $parent_hash->{response_headers}->header('ETag', $etag);
        $parent_hash->{response_headers}->header('Cache-Control', 'Public');
    }
    else {
        # no cache, no etags
        
        $resource_functions->{get_content}->($q, $parent_hash, $h, $hash);
        $parent_hash->{http_status} = RC_OK;
        $parent_hash->{response_headers}->last_modified($last_modified);
        $parent_hash->{response_headers}->header('Cache-Control', 'no-cache');
    }
}


# 'correct' HEAD functionality.
# needs a reference to a check_existence and get_modified_tags() function
sub HEAD {
    my ($q, $parent_hash, $h, $hash, $resource_functions) = @_;

    my $exists                 = $resource_functions->{check_existence}->($q, $parent_hash, $h, $hash);

    if (!$exists) {
        $parent_hash->{http_status} = RC_NOT_FOUND;
        $parent_hash->{content} = "404 - Not Found";
        return;
    }
    
    my ($last_modified, $etag) = $resource_functions->{get_modified_tags}->($q, $parent_hash, $h, $hash);
    my $if_modified_since      = $parent_hash->{request_headers}->if_modified_since;
    my $if_none_match          = $parent_hash->{request_headers}->header('if-none-match');
    
    if (
        ($if_modified_since && $last_modified <= $if_modified_since)
        ||
        ($if_none_match     && $etag eq $if_none_match)
        ) {
        # don't need to send anything back;
        $parent_hash->{http_content} = "";
        $parent_hash->{http_status} = RC_NOT_MODIFIED;
        $parent_hash->{response_headers}->last_modified($last_modified);
        $parent_hash->{response_headers}->header('ETag', $etag);
        return;
    }

    # get the contents and populate the hash as needed
    $parent_hash->{http_content} = '';
    $parent_hash->{http_status} = RC_OK;
    $parent_hash->{response_headers}->last_modified($last_modified);
    $parent_hash->{response_headers}->header('ETag', $etag);
}



# 'correct' PUT functionality.
# needs a the following funcitons :
#  get content
#  put content
#  get_modified_tags
sub PUT {
    my ($q, $parent_hash, $h, $hash, $resource_functions) = @_;


    my $status = $resource_functions->{put_content}->($q, $parent_hash, $h, $hash);
    $parent_hash->{http_status} = $status;  # not 201 CREATED because we want it to look just like an update
 
    return unless $status == RC_OK;
    
    my ($last_modified, $etag) = $resource_functions->{get_modified_tags}->($q, $parent_hash, $h, $hash);

    # get the contents and populate the hash as needed
    $resource_functions->{get_content}->($q, $parent_hash, $h, $hash);
    $parent_hash->{response_headers}->last_modified($last_modified);
    $parent_hash->{response_headers}->header('ETag', $etag);
}

# 'correct' DELETE functionality.
# needs a the following funcitons :
#  delete_resource
sub DELETE {
    my ($q, $parent_hash, $h, $hash, $resource_functions) = @_;


    $hash->{http_status} = $resource_functions->{delete_resource}->($q, $parent_hash, $h, $hash);
    $hash->{http_content} = '';
}


sub deleteFile {
    my ($q, $parent_hash, $h, $hash) = @_;
    my $file_name = $hash->{_resource_file_name};

    unlink $file_name;

    
    if (-e $file_name) {
        $parent_hash->{http_content} = "500 - Internal Server Error";
        return RC_INTERNAL_SERVER_ERROR;
    }
    return RC_NO_CONTENT;
}



sub checkExistenceForFile {
    my ($q, $parent_hash, $h, $hash) = @_;
    my $file_name = $hash->{_resource_file_name};

    return -e $file_name;
}



sub getModifiedTagsForFile {
    my ($q, $parent_hash, $h, $hash) = @_;
    my $file_name = $hash->{_resource_file_name};

    my @stat = stat($file_name);
    my $last_modified = $stat[9];
    my $etag = $stat[7].$stat[9];

    return ($last_modified, $etag);
}


sub getContentForTextFile {
    my ($q, $parent_hash, $h, $hash) = @_;
    my $file_name = $hash->{_resource_file_name};

    if (open (F, "$file_name")) {
        my @lines = <F>;
        close F;

        $hash->{file_contents}  = join("", map { s/\r//; $_; } @lines);
        $hash->{full_file_name} = $file_name;

        my $ph;
        for ($ph = $parent_hash; $ph->{parent} && $ph->{parent} != $ph; $ph = $ph->{parent}) {
            ;
        }

        my $config = $ph->{config};

        if ($ph->{request}->uri !~ /^\/rest/) { 
            foreach my $ctp (@{$config->{click_through_path}}) {
                $hash->{file_contents} =~ s!($ctp[\S]+)!<a href="/viewFile.html/$1">$1</a>!g;
            }
        }
        
    }
}    


sub putContentForTextFile {
    my ($q, $parent_hash, $h, $hash) = @_;
    my $file_name = $hash->{_resource_file_name};

    if (!defined($h->{file_contents})) {
        return RC_BAD_REQUEST;
    }

    if (open (F, ">$file_name")) {
        $h->{file_contents} =~ s/\r//g;
        print F $h->{file_contents};
        close F;
        return RC_OK;
    }
    else {
        $parent_hash->{http_content} = "500 - Internal Server Error";
        return RC_INTERNAL_SERVER_ERROR;
    }
}    

sub getDirListing {
    my ($q, $parent_hash, $h, $hash) = @_;
    my $dir = $hash->{_resource_file_name};

    if (opendir(DIR, $dir)) {
        my @files = grep { -f "$dir/$_" } readdir(DIR);
        closedir DIR;
        my $n0 = 0;
        my $regex = $h->{regex};
        $hash->{files} = [];
        my $oe = 'odd';
        my $last_modified;
        my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst);
                                                               

        if ($regex) {
            $regex =~ s/[^\^a-z0-9_:\+\*\|\(\)\!\.\{\}\\]//ig;
            $hash->{regex} = $regex;
            my $r = qr/$regex/;
            foreach my $file (grep {/$r/} @files) {
                $oe = (($oe eq 'odd') ? 'even' : 'odd');;
                $last_modified = (stat("$dir/$file"))[9];
                ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($last_modified);
                $last_modified = sprintf("%4d/%02d/%02d %02d:%02d:%02d", $year+1900, $mon+1, $mday, $hour, $min, $sec);
                push (@{$hash->{files}}, { file_name => $file,
                                           n0        => $n0,
                                           n1        => $n0 + 1,
                                           oddeven   => !($n0 % 2),
                                           oe        => $oe,
                                           last_mod  => $last_modified,
                      });
                $n0++;
            }
        }
        else { 
            foreach my $file (@files) {
                $oe = (($oe eq 'odd') ? 'even' : 'odd');;
                $last_modified = (stat("$dir/$file"))[9];
                ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($last_modified);
                $last_modified = sprintf("%4d/%02d/%02d %02d:%02d:%02d", $year+1900, $mon+1, $mday, $hour, $min, $sec);
                push (@{$hash->{files}}, { file_name => $file,
                                           n0        => $n0,
                                           n1        => $n0 + 1,
                                           oddeven   => !($n0 % 2),
                                           oe        => $oe,
                                           last_mod  => $last_modified,
                      });
                $n0++;
            }
        }
        $hash->{no_files} = (@{$hash->{files}})? 1 : 0;
    }
}
    


                

1;
