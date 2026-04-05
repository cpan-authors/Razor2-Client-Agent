#!perl

use strict;
use warnings;

use Test::More;

# Test Syslog module structure without requiring a UDP socket
# (new() creates a socket, so we test the data tables and send() logic)

use_ok('Razor2::Syslog');

# === Verify syslog facility table completeness ===
# RFC 5424 defines local0-local7 (codes 16-23)

# Access the facility table via a test instance.
# We need to mock the socket creation to avoid needing UDP.
{
    no warnings 'redefine';
    my $orig_new = \&IO::Socket::IP::new;
    local *IO::Socket::IP::new = sub {
        # Return a fake socket object that supports send() and flush()
        return bless {}, 'Razor2::Syslog::TestSocket';
    };

    {
        package Razor2::Syslog::TestSocket;
        sub send  { return 1; }
        sub flush { return 1; }
    }

    my $syslog = Razor2::Syslog->new( Facility => 'local7' );
    ok( defined $syslog, 'Syslog object created with local7 facility' );

    # Test that local7 produces correct priority value
    # Facility local7 = 23, priority err = 3
    # Expected: (23 << 3) | 3 = 187
    my $sent_msg;
    {
        no warnings 'redefine';
        local *Razor2::Syslog::TestSocket::send = sub {
            my ( $self, $msg ) = @_;
            $sent_msg = $msg;
            return 1;
        };
        $syslog->send('test message');
    }
    like( $sent_msg, qr/^<187>/, 'local7 + err produces correct syslog priority 187' );

    # Test all local facilities (local0=16 through local7=23)
    for my $i ( 0 .. 7 ) {
        my $facility = "local$i";
        my $s        = Razor2::Syslog->new( Facility => $facility, Priority => 'debug' );
        ok( defined $s, "Syslog object created with $facility" );

        my $captured;
        {
            no warnings 'redefine';
            local *Razor2::Syslog::TestSocket::send = sub {
                my ( $self, $msg ) = @_;
                $captured = $msg;
                return 1;
            };
            $s->send('test');
        }
        my $expected_code = ( ( 16 + $i ) << 3 ) | 7;    # facility | debug priority
        like( $captured, qr/^<$expected_code>/,
            "$facility + debug produces correct priority $expected_code" );
    }
}

# === Verify unknown facility falls back to 21 (local5) ===
{
    no warnings 'redefine';
    local *IO::Socket::IP::new = sub {
        return bless {}, 'Razor2::Syslog::TestSocket';
    };

    my $syslog = Razor2::Syslog->new( Facility => 'nonexistent' );
    my $captured;
    {
        no warnings 'redefine';
        local *Razor2::Syslog::TestSocket::send = sub {
            my ( $self, $msg ) = @_;
            $captured = $msg;
            return 1;
        };
        $syslog->send('fallback test');
    }
    # Unknown facility defaults to 21, priority err = 3
    # (21 << 3) | 3 = 171
    like( $captured, qr/^<171>/, 'unknown facility falls back to code 21 (local5)' );
}

done_testing;
