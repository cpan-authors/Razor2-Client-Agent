requires 'Digest::SHA';
requires 'File::Copy';
requires 'File::Spec';
requires 'File::Temp';
requires 'Getopt::Long';
requires 'IO::Socket::IP';
requires 'MIME::Base64';
requires 'Time::HiRes';
requires 'URI::Escape';
requires 'parent';

on 'test' => sub {
    requires 'File::Temp';
    requires 'Test::More';
};
