#!/usr/local/bin/perl
use Crypt::Eksblowfish::Bcrypt;
use Crypt::Random;

$password = 'bigtest';
$encrypted = encrypt_password($password);
print "$password is encrypted as $encrypted\n";

print "Yes the password is $password\n" if check_password($password, $encrypted);
print "No the password is not smalltest\n" if !check_password('smalltest', $encrypted);

# Encrypt a password 
sub encrypt_password {
    my $password = shift;

    # Generate a salt if one is not passed
    my $salt = shift || salt(); 

    # Set the cost to 8 and append a NUL
    my $settings = '$2a$08$'.$salt;

    # Encrypt it
    return Crypt::Eksblowfish::Bcrypt::bcrypt($password, $settings);
}

# Check if the passwords match
sub check_password {
    my ($plain_password, $hashed_password) = @_;

    # Regex to extract the salt
    if ($hashed_password =~ m!^\$2a\$\d{2}\$([A-Za-z0-9+\\.]{22})!) {

        # Use a letter by letter match rather than a complete string match to avoid timing attacks
        my $match = encrypt_password($plain_password, $1);
        my $bad = 0;
        for (my $n=0; $n < length $match; $n++) {
            $bad++ if substr($match, $n, 1) ne substr($hashed_password, $n, 1);
        }

        return $bad == 0;
    } else {
        return 0;
    }
}

# Return a random salt
sub salt {
    return Crypt::Eksblowfish::Bcrypt::en_base64(Crypt::Random::makerandom_octet(Length=>16));
}
