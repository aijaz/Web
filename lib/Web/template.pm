
package v3::template;

use strict;
use warnings;
use Data::Dumper;

sub readFile {
    my ($q, $file, $hash, $dbh, $session, $h) = @_;

    open FILE, "$file";
    my $fileContents = join("", <FILE>);
    close FILE;

    # top level hash
    $hash->{parent} = $hash unless $hash->{parent};
    
    return explode($q, $fileContents, $hash, $dbh, $session, $h, $hash);  # the second hash will always stay the same, and is the main top level hash

}


sub explode {
    my ($q, $template, $hash, $dbh, $session, $h, $top_hash) = @_;

    $template =~ s/<recurse ([a-zA-Z0-9_]*) ([a-zA-Z0-9_]*) *\](.*?)\[\/recurse \1\]/doRecurse($q, $hash, $1, $2, $3, $dbh, $session, $top_hash)/ges;

    $template =~ s/<aoh(\S+)\s+a=([^\>]+)>(.*?)<\/aoh\1>/doAoh($q, $hash, $2, $3, $dbh, $session)/ges;
    
    $template =~ s/<if(\S+) c=([^\>]+)>(.*?)<\/if\1>\s*<else\1>(.*?)<\/else\1>/doIf($q, $hash, $2, $3, $4, $dbh, $session)/ges;
    
    while ($template =~ s/\$([\:a-zA-Z0-9_]+)/doVal($hash, $1)/ges) {
        ;
    }
        
    $template =~ s/<include ([a-zA-Z0-9_:]+) +([a-zA-Z0-9\/\._]+) *\/>/doFile($q, $hash, $1, $2, $dbh, $session, $h, $top_hash)/ges;
    
    return $template;

}


sub doFile {
    my ($q, $hash, $module, $file, $dbh, $session, $h, $top_hash) = @_;
    my $doc_root = $ENV{DOCUMENT_ROOT}."";

    if (eval "require $module") {
        my $moduleHash = eval ("\&$module"."::handle(\$q, \$file, \$hash, \$dbh, \$session, \$h, \$top_hash)");

        if ($@) {
            print "\n\n<h1>**** CANNOT EXECUTE $module *****</h1><pre>$@</pre>\n\n";
            return '';
        }
        else {
            $moduleHash->{parent} = $hash;
            if (open FILE, "$doc_root/$file") {
                my $fileContents = join("", <FILE>);
                close FILE;
                my $template =  explode($q, $fileContents, $moduleHash, $dbh, $session, $h, $top_hash);
                # copy the cookie and login_required, so that they bubble upwards all the way to go or ajax
                foreach (qw(REDIRECT cookie login_required)) { 
                    $hash->{$_} = $moduleHash->{$_};
                };
                return $template;
            }
            return '';
        }
    }
    else {
        print "\n\n<h1>**** CANNOT REQUIRE the module $module *****</h1><pre>$@</pre>\n\n";
        return '';
    }
}

sub doRecurse {
    my ($q, $hash, $arrayName, $varToRecurseOn, $chunk, $dbh, $session) = @_;


    my $ret = "<div class=$arrayName>";
    my $h;
    my $elt;
    my $ref;

    if ($hash->{$varToRecurseOn}) {
        $ref = ref($hash->{$varToRecurseOn});
        if ($ref eq 'HASH') {
            $hash->{$varToRecurseOn}->{parent} = $hash;
            $ret .= explode($q, $chunk, $hash->{$varToRecurseOn}, $dbh, $session);
            $chunk = "\[r $arrayName $varToRecurseOn\]$chunk\[/r $arrayName\]";
            $ret .= explode($q, $chunk, $hash->{$varToRecurseOn}, $dbh, $session);
        }
        elsif ($ref eq 'ARRAY') {
            foreach $elt (@{$hash->{$varToRecurseOn}}) {
                $elt->{parent} = $hash;
                $ret .= explode($q, $chunk, $elt, $dbh, $session);
            }
            $chunk = "\[r $arrayName $varToRecurseOn\]$chunk\[/r $arrayName\]";
            foreach $elt (@{$hash->{$varToRecurseOn}}) {
                $elt->{parent} = $hash;
                $ret .= explode($q, $chunk, $elt, $dbh, $session);
            }
        }
    }
    else {
        return '';
    }

    $ret .= "</div>" ;
    return $ret;
}

sub doIf {
    my ($q, $hash, $cond, $ifVal, $elseVal, $dbh, $session) = @_;

    if ( (exists($hash->{$cond}) && $hash->{$cond})) {
        return explode($q, $ifVal, $hash, $dbh, $session);
    }
    return explode($q, $elseVal, $hash, $dbh, $session);
}

sub doVal {
    my ($hash, $k) = @_;

    while ($k =~ /^PARENT::(.*)/) {
        $k = $1; 
        $hash = $hash->{parent};
    }
    
    return $hash->{$k} if defined $hash->{$k};
    return '';
}

sub doAoh {
    my ($q, $hash, $arrayName, $chunk, $dbh, $session) = @_;

    my $ret = '';
    my $h;

    foreach $h (@{$hash->{$arrayName}}) {
        $h->{parent} = $hash;
        $ret .= explode($q, $chunk, $h, $dbh, $session);
    }

    return $ret;
}


1;
