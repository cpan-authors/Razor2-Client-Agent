requires 'Digest::SHA';
requires 'File::Copy';
requires 'File::Spec';
requires 'Getopt::Long';
requires 'IO::Socket::IP';
requires 'MIME::Base64';
requires 'Time::HiRes';
requires 'URI::Escape';

on 'test' => sub {
    requires 'File::Temp';
    requires 'Test::More';
};
