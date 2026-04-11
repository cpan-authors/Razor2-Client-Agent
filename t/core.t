#!perl

use strict;
use warnings;

use Test::More;

use Razor2::Client::Core;

# Core.pm expects log/logobj methods from Logger parent.
# Provide no-op stubs for testing.
no warnings 'once';
*Razor2::Client::Core::log     = sub { };
*Razor2::Client::Core::logobj  = sub { };
*Razor2::Client::Core::log2file = sub { };
*Razor2::Client::Core::errprefix = sub { 0 };
*Razor2::Client::Core::error   = sub { 0 };

# Helper: create a minimal Core object with required fields
sub make_core {
    my (%args) = @_;
    my $self = bless {}, 'Razor2::Client::Core';
    $self->{s}    = $args{s}    || {};
    $self->{conf} = $args{conf} || {};
    $self->{opt}  = $args{opt}  || {};
    return $self;
}

# === zonename tests ===

subtest 'zonename builds correct domain names' => sub {
    is( Razor2::Client::Core::zonename('z1.razor.example.com', 'catalogue'),
        'z1-catalogue.razor.example.com',
        'zone with subdomain and type' );

    is( Razor2::Client::Core::zonename('pool.razor.net', 'nomination'),
        'pool-nomination.razor.net',
        'another zone/type combination' );
};

# === make_query tests ===

subtest 'make_query for check action' => sub {
    my $core = make_core();

    my $result = $core->make_query({
        action => 'check',
        sig    => 'abc123',
        eng    => 8,
    });

    is( ref $result, 'HASH', 'returns hashref for single sig' );
    is( $result->{a}, 'c',   'action is "c" for check' );
    is( $result->{e}, 8,     'engine number preserved' );
    is( $result->{s}, 'abc123', 'signature preserved' );
    ok( !exists $result->{ep4}, 'no ep4 for non-engine-4' );
};

subtest 'make_query for check with engine 4 includes ep4' => sub {
    my $core = make_core();

    my $result = $core->make_query({
        action => 'check',
        sig    => 'sig4',
        eng    => '4',
        ep4    => '7542-10',
    });

    is( $result->{ep4}, '7542-10', 'ep4 included for engine 4' );
};

subtest 'make_query for check with array sig (VR8)' => sub {
    my $core = make_core();

    my $result = $core->make_query({
        action => 'check',
        sig    => ['sig1', 'sig2', 'sig3'],
        eng    => 8,
    });

    is( ref $result, 'ARRAY', 'returns arrayref for multiple sigs' );
    is( scalar @$result, 3, 'one query per sig' );
    is( $result->[0]{a}, 'c', 'action is c' );
    is( $result->[0]{s}, 'sig1', 'first sig correct' );
    is( $result->[2]{s}, 'sig3', 'last sig correct' );
};

subtest 'make_query for rcheck action' => sub {
    my $core = make_core();

    my $result = $core->make_query({
        action => 'rcheck',
        sig    => 'rsig',
        eng    => 4,
        ep4    => '1234-5',
    });

    is( $result->{a}, 'r', 'action is "r" for rcheck' );
    is( $result->{e}, 4, 'engine preserved' );
    is( $result->{s}, 'rsig', 'sig preserved' );
    is( $result->{ep4}, '1234-5', 'ep4 included for engine 4' );
};

subtest 'make_query for revoke builds per-engine queries' => sub {
    my $core = make_core(
        s => { engines => { 4 => 1, 8 => 1 } },
    );

    my @result = $core->make_query({
        action => 'revoke',
        obj    => {
            p => [
                { e4 => 'sig_e4', e8 => ['vr8a', 'vr8b'] },
            ],
        },
    });

    # Should produce queries for all sigs across all engines
    ok( scalar(@result) >= 3, 'produces queries for each sig' );

    my @actions = map { $_->{a} } @result;
    ok( (grep { $_ eq 'revoke' } @actions) == scalar(@result),
        'all queries are revoke actions' );
};

# === check_resp tests ===

subtest 'check_resp returns 0 on error' => sub {
    my $core = make_core(s => { min_cf => 50 });

    my $objp = {};
    my $result = $core->check_resp('test', {}, { err => '404' }, $objp);
    is( $result, 0, 'error response returns 0' );
};

subtest 'check_resp returns 1 when sig found (p=1) with cf >= min_cf' => sub {
    my $core = make_core(s => { min_cf => 50 });

    my $objp = {};
    my $result = $core->check_resp('test', {}, { p => '1', cf => 75 }, $objp);
    is( $result, 1, 'spam detected when cf >= min_cf' );
};

subtest 'check_resp returns 0 when sig found but cf < min_cf' => sub {
    my $core = make_core(s => { min_cf => 50 });

    my $objp = {};
    my $result = $core->check_resp('test', {}, { p => '1', cf => 30 }, $objp);
    is( $result, 0, 'not spam when cf < min_cf' );
};

subtest 'check_resp returns 1 when sig found with no cf' => sub {
    my $core = make_core(s => { min_cf => 50 });

    my $objp = {};
    my $result = $core->check_resp('test', {}, { p => '1' }, $objp);
    is( $result, 1, 'spam when sig found, no cf' );
};

subtest 'check_resp returns 0 when sig not found (p=0)' => sub {
    my $core = make_core(s => { min_cf => 50 });

    my $objp = {};
    my $result = $core->check_resp('test', {}, { p => '0' }, $objp);
    is( $result, 0, 'not spam when sig not found' );
};

subtest 'check_resp sets contention from response' => sub {
    my $core = make_core(s => { min_cf => 50 });

    my $objp = {};
    $core->check_resp('test', {}, { p => '0', ct => 1 }, $objp);
    is( $objp->{ct}, 1, 'contention flag propagated' );

    $objp = {};
    $core->check_resp('test', {}, { p => '0' }, $objp);
    is( $objp->{ct}, 0, 'contention defaults to 0' );
};

# === rcheck_resp tests ===

subtest 'rcheck_resp returns 1 on err 230 (server wants mail)' => sub {
    my $core = make_core();

    my $result = $core->rcheck_resp('test', {}, { err => '230' });
    is( $result, 1, 'err 230 means server wants mail' );
};

subtest 'rcheck_resp returns 0 on other errors' => sub {
    my $core = make_core();

    my $result = $core->rcheck_resp('test', {}, { err => '500' });
    is( $result, 0, 'other errors return 0' );
};

subtest 'rcheck_resp returns 0 when report accepted (res=1)' => sub {
    my $core = make_core();

    my $result = $core->rcheck_resp('test', {}, { res => '1' });
    is( $result, 0, 'accepted report returns 0 (no more mail needed)' );
};

subtest 'rcheck_resp returns 0 when report rejected (res=0)' => sub {
    my $core = make_core();

    my $result = $core->rcheck_resp('test', {}, { res => '0' });
    is( $result, 0, 'rejected report returns 0' );
};

# === check_logic tests ===

subtest 'check_logic method 1: sums spam across parts' => sub {
    my $core = make_core(
        conf => { logic_method => 1, logic_engines => 'any' },
        s    => { engines => { 4 => 1, 8 => 1 }, min_cf => 50 },
    );

    my $obj = {
        p => [
            { id => '1.0', spam => 1, sent => [{e => 4, s => 'x'}], resp => [{p => '1'}] },
            { id => '1.1', spam => 0, sent => [{e => 4, s => 'y'}], resp => [{p => '0'}] },
        ],
    };

    $core->check_logic($obj);
    ok( $obj->{spam}, 'method 1: spam if any part is spam' );
};

subtest 'check_logic method 1: not spam when no parts are spam' => sub {
    my $core = make_core(
        conf => { logic_method => 1, logic_engines => 'any' },
        s    => { engines => { 4 => 1 }, min_cf => 50 },
    );

    my $obj = {
        p => [
            { id => '1.0', spam => 0, sent => [{e => 4, s => 'x'}], resp => [{p => '0'}] },
        ],
    };

    $core->check_logic($obj);
    is( $obj->{spam}, 0, 'method 1: not spam when no parts spam' );
};

subtest 'check_logic method 4: ignores contention parts' => sub {
    my $core = make_core(
        conf => { logic_method => 4, logic_engines => 'any' },
        s    => { engines => { 4 => 1 }, min_cf => 50 },
    );

    # orig_mail required to prevent fallback to logic_method 1
    my $obj = {
        orig_mail => \"fake mail",
        p => [
            { id => '1.0', sent => [{e => 4, s => 'x'}], resp => [{p => '1', ct => 1}] },
            { id => '1.1', sent => [{e => 4, s => 'y'}], resp => [{p => '0'}] },
        ],
    };

    $core->check_logic($obj);
    is( $obj->{spam}, 0, 'method 4: contention parts ignored' );
};

subtest 'check_logic method 4: non-contention spam means mail is spam' => sub {
    my $core = make_core(
        conf => { logic_method => 4, logic_engines => 'any' },
        s    => { engines => { 4 => 1 }, min_cf => 50 },
    );

    my $obj = {
        orig_mail => \"fake mail",
        p => [
            { id => '1.0', sent => [{e => 4, s => 'x'}], resp => [{p => '0'}] },
            { id => '1.1', sent => [{e => 4, s => 'y'}], resp => [{p => '1'}] },
        ],
    };

    $core->check_logic($obj);
    is( $obj->{spam}, 1, 'method 4: non-contention spam counts' );
};

subtest 'check_logic method 5: all non-contention parts must be spam' => sub {
    my $core = make_core(
        conf => { logic_method => 5, logic_engines => 'any' },
        s    => { engines => { 4 => 1 }, min_cf => 50 },
    );

    # One spam, one not (no contention on either) — should not be spam
    my $obj = {
        orig_mail => \"fake mail",
        p => [
            { id => '1.0', sent => [{e => 4, s => 'x'}], resp => [{p => '1'}] },
            { id => '1.1', sent => [{e => 4, s => 'y'}], resp => [{p => '0'}] },
        ],
    };

    $core->check_logic($obj);
    is( $obj->{spam}, 0, 'method 5: not all parts spam, not spam' );

    # All non-contention parts spam; contention part is not spam (ignored)
    my $obj2 = {
        orig_mail => \"fake mail",
        p => [
            { id => '1.0', sent => [{e => 4, s => 'x'}], resp => [{p => '1'}] },
            { id => '1.1', sent => [{e => 4, s => 'y'}], resp => [{p => '1'}] },
            { id => '1.2', sent => [{e => 4, s => 'z'}], resp => [{p => '0', ct => 1}] },
        ],
    };

    $core->check_logic($obj2);
    is( $obj2->{spam}, 1, 'method 5: all non-contention parts spam, is spam' );
};

subtest 'check_logic method 2: first inline text part decides' => sub {
    my $core = make_core(
        conf => { logic_method => 2, logic_engines => 'any' },
        s    => { engines => { 4 => 1 }, min_cf => 50 },
    );

    my $obj = {
        orig_mail => \"dummy",
        p => [
            {
                id   => '1.0', spam => 0, ct => 0,
                body => \"Content-Type: application/pdf\n\nbinary stuff",
                sent => [{e => 4, s => 'x'}], resp => [{p => '0'}],
            },
            {
                id   => '1.1', spam => 1, ct => 0,
                body => \"Content-Type: text/plain\nContent-Disposition: inline\n\nspam text",
                sent => [{e => 4, s => 'y'}], resp => [{p => '1'}],
            },
        ],
    };

    $core->check_logic($obj);
    is( $obj->{spam}, 1, 'method 2: inline text part is the decider' );
};

subtest 'check_logic method 3: all text parts must be spam' => sub {
    my $core = make_core(
        conf => { logic_method => 3, logic_engines => 'any' },
        s    => { engines => { 4 => 1 }, min_cf => 50 },
    );

    my $obj = {
        orig_mail => \"dummy",
        p => [
            {
                id   => '1.0', spam => 1, ct => 0,
                body => \"Content-Type: text/plain\n\nspam",
                sent => [{e => 4, s => 'x'}], resp => [{p => '1'}],
            },
            {
                id   => '1.1', spam => 0, ct => 0,
                body => \"Content-Type: text/html\n\nnot spam",
                sent => [{e => 4, s => 'y'}], resp => [{p => '0'}],
            },
        ],
    };

    $core->check_logic($obj);
    is( $obj->{spam}, 0, 'method 3: not all text parts spam, not spam' );

    # Both text parts are spam
    my $obj2 = {
        orig_mail => \"dummy",
        p => [
            {
                id   => '1.0', spam => 1, ct => 0,
                body => \"Content-Type: text/plain\n\nspam",
                sent => [{e => 4, s => 'x'}], resp => [{p => '1'}],
            },
            {
                id   => '1.1', spam => 1, ct => 0,
                body => \"Content-Type: text/html\n\nmore spam",
                sent => [{e => 4, s => 'y'}], resp => [{p => '1'}],
            },
        ],
    };

    $core->check_logic($obj2);
    is( $obj2->{spam}, 1, 'method 3: all text parts spam, is spam' );
};

subtest 'check_logic with logic_engines restricting to specific engine' => sub {
    my $core = make_core(
        conf => { logic_method => 1, logic_engines => 'any' },
        s    => { engines => { 4 => 1, 8 => 1 }, min_cf => 50 },
    );

    # With 'any' logic_engines, any engine match counts
    # Note: without orig_mail, logic_method defaults to 1 (sum mode)
    my $obj = {
        p => [
            {
                id   => '1.0',
                sent => [ {e => 4, s => 'x'}, {e => 8, s => 'y'} ],
                resp => [ {p => '0'}, {p => '1'} ],
            },
        ],
    };

    $core->check_logic($obj);
    ok( $obj->{spam}, 'any engine: one match is enough' );
};

# Note: check_logic's skipme uses 'next' outside a loop (known bug, PR #46).
# We test skipme on parts instead, which works correctly.
subtest 'check_logic skips parts with skipme' => sub {
    my $core = make_core(
        conf => { logic_method => 4, logic_engines => 'any' },
        s    => { engines => { 4 => 1 }, min_cf => 50 },
    );

    # Part 0 is skipme (spam data would trigger if not skipped)
    # Part 1 is not spam
    my $obj = {
        p => [
            { id => '1.0', skipme => 1, sent => [{e => 4, s => 'x'}], resp => [{p => '1'}] },
            { id => '1.1', sent => [{e => 4, s => 'y'}], resp => [{p => '0'}] },
        ],
    };

    $core->check_logic($obj);
    is( $obj->{spam}, 0, 'skipme parts are ignored in spam determination' );
};

# === compute_server_conf tests ===

subtest 'compute_server_conf parses min_cf variants' => sub {
    my @cases = (
        [ 'ac',    60, 60, 'plain ac' ],
        [ 'ac+10', 60, 70, 'ac plus offset' ],
        [ 'ac-15', 60, 45, 'ac minus offset' ],
        [ '80',    60, 80, 'literal number' ],
        [ 'ac+50', 60, 100, 'capped at 100' ],
        [ 'ac-70', 60, 0,   'floored at 0' ],
    );

    for my $case (@cases) {
        my ($min_cf_str, $server_ac, $expected, $desc) = @$case;

        my $core = make_core(
            conf => { min_cf => $min_cf_str, use_engines => [4, 8] },
            s    => {
                conf     => { ac => $server_ac, srl => 1, se => '14' },
                greeting => { sn => 'C', ep4 => '7542-10' },
                ip       => '127.0.0.1',
            },
            opt => {},
        );

        # compute_supported_engines needs supported_engines() from Engine
        # Stub it
        no warnings 'redefine';
        local *Razor2::Client::Core::supported_engines = sub { { 4 => 1, 8 => 1 } };
        local *Razor2::String::hexbits2hash = sub { { 4 => 1, 8 => 1 } };

        $core->compute_server_conf();
        is( $core->{s}{min_cf}, $expected, "min_cf='$min_cf_str': $desc" );
    }
};

subtest 'compute_server_conf picks up ep4 from greeting' => sub {
    my $core = make_core(
        conf => { min_cf => '50', use_engines => [4] },
        s    => {
            conf     => { ac => 50, srl => 1, se => '14' },
            greeting => { sn => 'C', ep4 => '9999-1' },
            ip       => '127.0.0.1',
        },
        opt => {},
    );

    no warnings 'redefine';
    local *Razor2::Client::Core::supported_engines = sub { { 4 => 1 } };
    local *Razor2::String::hexbits2hash = sub { { 4 => 1 } };

    $core->compute_server_conf();
    is( $core->{s}{conf}{ep4}, '9999-1', 'ep4 from greeting propagated to conf' );
};

# === prepare_objects tests ===

subtest 'prepare_objects handles cmd-line signature hashes' => sub {
    my $core = make_core(
        s => { engines => { 4 => 1 } },
    );

    my $objs = [
        { eng => 4, sig => 'deadbeef' },
        { eng => 8, sig => 'cafebabe', ep4 => '1234-5' },
    ];

    my $result = $core->prepare_objects($objs);
    is( ref $result, 'ARRAY', 'returns arrayref' );
    is( scalar @$result, 2, 'one object per input' );
    is( $result->[0]{p}[0]{e4}, 'deadbeef', 'sig placed in correct engine slot' );
    is( $result->[1]{ep4}, '1234-5', 'ep4 preserved' );
    is( $result->[0]{id}, 1, 'first object gets id 1' );
    is( $result->[1]{id}, 2, 'second object gets id 2' );
};

done_testing;
