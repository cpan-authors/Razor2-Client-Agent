#!perl

use strict;
use warnings;

use Test::More;

use Razor2::Client::Core;

# Core.pm needs log() from Logger inheritance. Provide a no-op stub.
no warnings 'once';
*Razor2::Client::Core::log   = sub { };
*Razor2::Client::Core::logll = sub { };

# === authenticate() must not crash when register() fails ===

subtest 'authenticate does not crash when register returns undef' => sub {
    my $core = Razor2::Client::Core->new;
    $core->{s} = {
        ip        => '127.0.0.1',
        port      => 2703,
        nomination => ['127.0.0.1'],
    };

    # Simulate the re-registration path: error 213 (unknown user) triggers
    # register() call. If register() fails (returns undef), authenticate()
    # must not crash dereferencing the return value.
    #
    # Mock _send to return error 213 first (triggering re-register),
    # and mock register to return undef (simulating failure).
    my $send_call = 0;
    no warnings 'redefine';
    local *Razor2::Client::Core::_send = sub {
        $send_call++;
        # Return SIS-encoded error 213 response
        return ["err=213\r\n"];
    };
    local *Razor2::Client::Core::connect = sub { return 1; };
    local *Razor2::Client::Core::register = sub { return; };

    my $result = $core->authenticate({ user => 'testuser', pass => 'testpass' });

    # Should return undef/0 (error), not crash
    ok( !$result, 'authenticate returns false on register failure' );
    like( $core->{errstr} || '', qr/213|authenticating/,
        'error message mentions the authentication failure' );
};

# === disconnect() properly cleans up connection state ===

subtest 'disconnect clears connection state' => sub {
    my $core = Razor2::Client::Core->new;

    # Simulate an active connection
    my $fake_sock = IO::Socket::IP->new(
        Listen    => 1,
        LocalAddr => '127.0.0.1',
        LocalPort => 0,
        Proto     => 'tcp',
    );
    plan skip_all => 'Cannot create test socket' unless $fake_sock;

    $core->{sock}         = $fake_sock;
    $core->{connected_to} = '127.0.0.1';
    $core->{select}       = IO::Select->new($fake_sock);

    # Mock _send to avoid actual network I/O
    no warnings 'redefine';
    local *Razor2::Client::Core::_send = sub { return []; };

    $core->disconnect();

    ok( !exists $core->{sock},         'sock deleted after disconnect' );
    ok( !exists $core->{select},       'select deleted after disconnect' );
    ok( !exists $core->{connected_to}, 'connected_to deleted after disconnect' );
};

done_testing;
