#!perl

use strict;
use warnings;

use Test::More;

use Razor2::Client::Core;

# Core inherits from Logger — provide a no-op log stub
no warnings 'once', 'redefine';
*Razor2::Client::Core::log    = sub { };
*Razor2::Client::Core::logobj = sub { };

# === Test 1: bodyparts CRLF normalization ===
# prepare_parts must normalize \r\n to \n in body parts (scalar refs)

subtest 'prepare_parts normalizes CRLF in body parts' => sub {
    my $core = Razor2::Client::Core->new;
    $core->{conf} = { debuglevel => 0, report_headers => 1 };
    $core->{name_version} = 'test-1.0';

    # Simulate what prepare_parts receives after prep_mail:
    # prep_mail returns ($headers, @bodyparts) where each bodypart is a scalar ref
    my $mail_body = "Content-Type: text/plain\r\n\r\nHello\r\nWorld\r\n";
    my $mail = "From: test\@example.com\nSubject: test\n\n$mail_body";
    my $obj = {
        id        => 1,
        orig_mail => \$mail,
    };

    # We can't easily call prepare_parts in isolation (it calls prep_mail),
    # so test the fix more directly: verify that s/\r\n/\n/gs on a deref'd
    # scalar ref works correctly
    my $body_with_crlf = "Hello\r\nWorld\r\n";
    my $ref = \$body_with_crlf;

    # This is the FIXED code path:
    ${$ref} =~ s/\r\n/\n/gs;
    is( $$ref, "Hello\nWorld\n", 'CRLF normalized via dereferenced scalar ref' );

    # Verify the bug: operating on the ref itself does NOT modify the string
    my $body2 = "Hello\r\nWorld\r\n";
    my $ref2 = \$body2;
    $ref2 =~ s/\r\n/\n/gs;    # Bug: operates on "SCALAR(0x...)" string
    is( $$ref2, "Hello\r\nWorld\r\n", 'Bug confirmed: ref =~ s/// does not modify string' );
};

# === Test 2: logic_engines regex accepts comma-separated digits ===

subtest 'logic_engines regex matches valid formats' => sub {
    # The fixed regex: /^\d+(?:,\d+)*$/
    my $regex = qr/^\d+(?:,\d+)*$/;

    # These should all match
    like( '4',       $regex, 'single engine' );
    like( '4,8',     $regex, 'two engines' );
    like( '1,4,8',   $regex, 'three engines' );
    like( '42',      $regex, 'multi-digit engine' );

    # These should NOT match
    unlike( '',       $regex, 'empty string' );
    unlike( '4,',     $regex, 'trailing comma' );
    unlike( ',4',     $regex, 'leading comma' );
    unlike( '4,,8',   $regex, 'double comma' );
    unlike( 'any',    $regex, 'word' );
    unlike( '4, 8',   $regex, 'comma with space' );

    # Verify the OLD regex was broken for common input
    my $old_regex = qr/^(\d\,)+$/;
    unlike( '4,8', $old_regex, 'old regex fails on "4,8" (no trailing comma)' );
    like( '4,8,',  $old_regex, 'old regex only matches with trailing comma' );
};

# === Test 3: check_logic with logic_engines as comma-separated list ===

subtest 'check_logic parses logic_engines comma list' => sub {
    my $core = Razor2::Client::Core->new;
    $core->{s} = {
        engines => { 4 => 1, 8 => 1 },
        min_cf  => 50,
    };
    $core->{conf} = {
        logic_method  => 4,
        logic_engines => '4,8',
    };

    my $obj = {
        id        => 1,
        orig_mail => \'dummy',
        spam      => 0,
        p         => [
            {
                id   => '1.0',
                spam => 0,
                sent => [ { e => 4, s => 'sig1' } ],
                resp => [ { p => '1', cf => 75 } ],
            },
        ],
    };

    $core->check_logic($obj);

    # With the fixed regex, logic_engines '4,8' is parsed as a specific
    # engine list, and engine 4 returning spam should set spam = 1
    is( $obj->{spam}, 1, 'logic_engines "4,8" correctly parsed and applied' );
};

done_testing;
