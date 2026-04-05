#!perl

use strict;
use warnings;

use Test::More;

use Razor2::Client::Core;

# Core inherits from Logger — provide a no-op log stub
no warnings 'once', 'redefine';
*Razor2::Client::Core::log    = sub { };
*Razor2::Client::Core::logobj = sub { };

# === make_query tests ===

subtest 'make_query check: engine 4 includes ep4' => sub {
    my $core = Razor2::Client::Core->new;
    my $q    = $core->make_query(
        {
            action => 'check',
            sig    => 'abc123',
            eng    => 4,
            ep4    => '7542-10',
        }
    );
    is( ref $q,     'HASH',      'returns hash ref for scalar sig' );
    is( $q->{a},    'c',         'action is c' );
    is( $q->{e},    4,           'engine is 4' );
    is( $q->{s},    'abc123',    'sig is correct' );
    is( $q->{ep4},  '7542-10',   'ep4 included for engine 4' );
};

subtest 'make_query check: engine 8 does not include ep4' => sub {
    my $core = Razor2::Client::Core->new;
    my $q    = $core->make_query(
        {
            action => 'check',
            sig    => 'def456',
            eng    => 8,
            ep4    => '7542-10',
        }
    );
    is( ref $q,     'HASH',      'returns hash ref' );
    is( $q->{e},    8,           'engine is 8' );
    ok( !exists $q->{ep4},       'ep4 NOT included for engine 8' );
};

subtest 'make_query check: array sigs (VR8)' => sub {
    my $core = Razor2::Client::Core->new;
    my $q    = $core->make_query(
        {
            action => 'check',
            sig    => [ 'sig1', 'sig2', 'sig3' ],
            eng    => 8,
        }
    );
    is( ref $q,     'ARRAY',     'returns array ref for multiple sigs' );
    is( scalar @$q, 3,           'three queries' );
    is( $q->[0]->{a}, 'c',      'action is c' );
    is( $q->[0]->{s}, 'sig1',   'first sig correct' );
    is( $q->[2]->{s}, 'sig3',   'third sig correct' );
};

subtest 'make_query rcheck: engine 4 includes ep4' => sub {
    my $core = Razor2::Client::Core->new;
    my $q    = $core->make_query(
        {
            action => 'rcheck',
            sig    => 'abc123',
            eng    => 4,
            ep4    => '7542-10',
        }
    );
    is( $q->{a},    'r',         'action is r' );
    is( $q->{ep4},  '7542-10',   'ep4 included for engine 4 rcheck' );
};

subtest 'make_query rcheck: engine 8 does not include ep4' => sub {
    my $core = Razor2::Client::Core->new;
    my $q    = $core->make_query(
        {
            action => 'rcheck',
            sig    => 'def456',
            eng    => 8,
            ep4    => '7542-10',
        }
    );
    is( $q->{a},    'r',         'action is r' );
    ok( !exists $q->{ep4},       'ep4 NOT included for engine 8 rcheck' );
};

# === check_resp tests ===

subtest 'check_resp: spam detected with sufficient confidence' => sub {
    my $core = Razor2::Client::Core->new;
    $core->{s}{min_cf} = 50;
    my $objp = {};
    my $result = $core->check_resp( 'test', {}, { p => '1', cf => 75 }, $objp );
    is( $result, 1, 'spam detected when cf >= min_cf' );
};

subtest 'check_resp: not spam when confidence too low' => sub {
    my $core = Razor2::Client::Core->new;
    $core->{s}{min_cf} = 50;
    my $objp = {};
    my $result = $core->check_resp( 'test', {}, { p => '1', cf => 25 }, $objp );
    is( $result, 0, 'not spam when cf < min_cf' );
};

subtest 'check_resp: not spam when sig not found' => sub {
    my $core = Razor2::Client::Core->new;
    $core->{s}{min_cf} = 50;
    my $objp = {};
    my $result = $core->check_resp( 'test', {}, { p => '0' }, $objp );
    is( $result, 0, 'not spam when p=0' );
};

subtest 'check_resp: contention flag propagated' => sub {
    my $core = Razor2::Client::Core->new;
    $core->{s}{min_cf} = 50;
    my $objp = {};
    $core->check_resp( 'test', {}, { p => '1', cf => 75, ct => 1 }, $objp );
    is( $objp->{ct}, 1, 'contention flag set from response' );
};

subtest 'check_resp: error response returns 0' => sub {
    my $core = Razor2::Client::Core->new;
    $core->{s}{min_cf} = 50;
    my $objp = {};
    my $result = $core->check_resp( 'test', {}, { err => '500' }, $objp );
    is( $result, 0, 'error response returns 0' );
};

done_testing;
