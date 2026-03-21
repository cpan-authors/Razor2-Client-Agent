#!perl

use strict;
use warnings;

use Test::More tests => 5;

use Razor2::Logger;

# Test 1: Logger can be created with LogTo => 'stdout'
{
    my $logger = Razor2::Logger->new(
        LogTo         => 'stdout',
        LogDebugLevel => 0,    # suppress bootup message
        LogPrefix     => 'test',
    );
    ok( $logger, "Logger created with LogTo => 'stdout'" );
    is( $logger->{LogType}, 'file', "stdout LogType is 'file' (uses file handle)" );
}

# Test 2: Logger with stdout actually writes to STDOUT
{
    my $output = '';
    local *STDOUT;
    open STDOUT, '>', \$output or die "Cannot redirect STDOUT: $!";

    my $logger = Razor2::Logger->new(
        LogTo         => 'stdout',
        LogDebugLevel => 5,
        LogPrefix     => 'test',
    );
    $logger->log( 1, "hello stdout" );
    like( $output, qr/hello stdout/, "Logger with stdout writes to STDOUT" );
}

# Test 3: Logger can be created with LogTo => 'stderr'
{
    my $logger = Razor2::Logger->new(
        LogTo         => 'stderr',
        LogDebugLevel => 0,
        LogPrefix     => 'test',
    );
    ok( $logger, "Logger created with LogTo => 'stderr'" );
    is( $logger->{LogType}, 'file', "stderr LogType is 'file' (uses file handle)" );
}
