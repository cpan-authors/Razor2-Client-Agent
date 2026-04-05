#!perl

use strict;
use warnings;

use Test::More;

# Test 1: check_logic returns early for skipme objects without warnings
subtest 'check_logic returns cleanly for skipme objects' => sub {
    use_ok('Razor2::Client::Core');

    # Create a minimal Core object with required methods
    my $core = bless {
        conf => { logic_method => 4, logic_engines => 'any' },
        s    => { engines => {} },
    }, 'Razor2::Client::Core';

    # Stub log method
    no warnings 'redefine', 'once';
    local *Razor2::Client::Core::log = sub { };

    my $obj = { skipme => 1, spam => 42 };

    # check_logic should return without warnings (not use 'next')
    my @warnings;
    local $SIG{__WARN__} = sub { push @warnings, $_[0] };
    $core->check_logic($obj);

    is( $obj->{spam}, 0, 'check_logic sets spam=0 for skipme objects' );
    is( scalar @warnings, 0, 'check_logic does not produce warnings for skipme' )
        or diag "Got warnings: @warnings";
};

# Test 2: reportit returns instead of exiting for simulate mode
subtest 'reportit returns for simulate mode' => sub {
    use_ok('Razor2::Client::Agent');

    # Create a minimal agent with enough structure for reportit to reach simulate check
    my $agent = bless {
        conf         => { simulate => 1 },
        opt          => { foreground => 1 },
        breed        => 'report',
        name_version => 'test-1.0',
        args         => '',
        s            => {},
        razorhome    => '/tmp',
    }, 'Razor2::Client::Agent';

    # Stub methods that reportit calls before reaching simulate check
    no warnings 'redefine';
    local *Razor2::Client::Agent::log             = sub { };
    local *Razor2::Client::Agent::get_ident       = sub { { user => 'test', pass => 'test' } };
    local *Razor2::Client::Agent::parse_mbox      = sub { ['fake mail'] };
    local *Razor2::Client::Agent::prepare_objects  = sub { [ { id => 1 } ] };
    local *Razor2::Client::Agent::get_server_info  = sub { 1 };
    local *Razor2::Client::Agent::compute_sigs     = sub { ['sig1'] };

    my $rc = $agent->reportit({});
    is( $rc, 1, 'reportit returns 1 for simulate mode instead of exiting' );
};

# Test 3: reportit returns for printhash mode
subtest 'reportit returns for printhash mode' => sub {

    my $agent = bless {
        conf         => {},
        opt          => { foreground => 1, printhash => 1 },
        breed        => 'report',
        name_version => 'test-1.0',
        args         => '',
        s            => {},
        razorhome    => '/tmp',
    }, 'Razor2::Client::Agent';

    no warnings 'redefine';
    local *Razor2::Client::Agent::log             = sub { };
    local *Razor2::Client::Agent::get_ident       = sub { { user => 'test', pass => 'test' } };
    local *Razor2::Client::Agent::parse_mbox      = sub { ['fake mail'] };
    local *Razor2::Client::Agent::prepare_objects  = sub { [ { id => 1 } ] };
    local *Razor2::Client::Agent::get_server_info  = sub { 1 };
    local *Razor2::Client::Agent::compute_sigs     = sub { ['e4: sig1'] };

    # Capture STDOUT from the print statements
    my $output = '';
    open my $capture, '>', \$output;
    my $old_stdout = select $capture;

    my $rc = $agent->reportit({});

    select $old_stdout;
    close $capture;

    is( $rc, 1, 'reportit returns 1 for printhash mode instead of exiting' );
};

# Test 4: reportit returns for empty objects
subtest 'reportit returns for no valid objects' => sub {

    my $agent = bless {
        conf         => {},
        opt          => { foreground => 1 },
        breed        => 'report',
        name_version => 'test-1.0',
        args         => '',
        s            => {},
        razorhome    => '/tmp',
    }, 'Razor2::Client::Agent';

    no warnings 'redefine';
    local *Razor2::Client::Agent::log             = sub { };
    local *Razor2::Client::Agent::get_ident       = sub { { user => 'test', pass => 'test' } };
    local *Razor2::Client::Agent::parse_mbox      = sub { ['fake mail'] };
    local *Razor2::Client::Agent::prepare_objects  = sub { [] };
    local *Razor2::Client::Agent::get_server_info  = sub { 1 };
    local *Razor2::Client::Agent::compute_sigs     = sub { ['sig1'] };

    my $rc = $agent->reportit({});
    is( $rc, 1, 'reportit returns 1 for empty objects instead of exiting' );
};

done_testing;
