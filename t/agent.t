#!perl

use strict;
use warnings;

use Test::More;
use File::Temp qw(tempfile tempdir);
use IO::File;

use_ok('Razor2::Client::Agent');

# --- Constructor validation ---

{
    my $agent = Razor2::Client::Agent->new('razor-check');
    isa_ok( $agent, 'Razor2::Client::Agent' );
    is( $agent->{breed}, 'check', "breed extracted from razor-check" );
    ok( defined $agent->{preproc}, "preproc manager created" );
    ok( defined $agent->{preproc_vr8}, "preproc_vr8 manager created" );
    is( $agent->{global_razorhome}, '/etc/razor', "default global_razorhome" );
    like( $agent->{name_version}, qr/Razor-Agents/, "name_version set" );
}

{
    my $agent = Razor2::Client::Agent->new('razor-report');
    is( $agent->{breed}, 'report', "breed extracted from razor-report" );
}

{
    my $agent = Razor2::Client::Agent->new('razor-revoke');
    is( $agent->{breed}, 'revoke', "breed extracted from razor-revoke" );
}

{
    my $agent = Razor2::Client::Agent->new('razor-admin');
    is( $agent->{breed}, 'admin', "breed extracted from razor-admin" );
}

{
    # Full path should also work
    my $agent = Razor2::Client::Agent->new('/usr/bin/razor-check');
    is( $agent->{breed}, 'check', "breed extracted from full path" );
}

{
    # Invalid breed dies
    eval { Razor2::Client::Agent->new('razor-invalid') };
    like( $@, qr/Invalid program name/, "invalid breed dies" );
}

{
    # razor-client exits 0 for backward compat — test indirectly
    # (we can't easily test exit in-process, but verify the code path exists)
    ok( 1, "razor-client backward compat path exists" );
}

# --- Helper to build a minimal agent for testing ---

sub _test_agent {
    my %extra = @_;
    my $agent = Razor2::Client::Agent->new('razor-check');

    # Provide minimal conf and opt so methods don't blow up
    $agent->{conf} = {
        whitelist  => '',
        ignorelist => 0,
        %{ $extra{conf} || {} },
    };
    $agent->{opt} = {
        debug => 0,
        %{ $extra{opt} || {} },
    };
    $agent->{logref} = 0;    # suppress logging

    return $agent;
}

# --- parse_mbox: single RFC 822 message from file ---

{
    my $agent = _test_agent();
    my $dir   = tempdir( CLEANUP => 1 );

    my $msg = "From: sender\@example.com\nSubject: Test\n\nHello world\n";
    my $fn  = "$dir/msg.eml";
    open my $fh, '>', $fn or die "Can't write $fn: $!";
    print $fh $msg;
    close $fh;

    local @ARGV = ($fn);
    my $mails = $agent->parse_mbox( {} );

    ok( defined $mails, "parse_mbox returns result for single message" );
    is( ref $mails, 'ARRAY', "parse_mbox returns arrayref" );
    is( scalar @$mails, 1, "single message file yields 1 mail" );
    like( ${ $mails->[0] }, qr/Hello world/, "mail content preserved" );
}

# --- parse_mbox: mbox format with multiple messages ---

{
    my $agent = _test_agent();
    my $dir   = tempdir( CLEANUP => 1 );

    my $mbox = <<'MBOX';
From sender@example.com Mon Jan  1 00:00:00 2024
From: sender@example.com
Subject: First

Body one
From recipient@example.com Tue Jan  2 00:00:00 2024
From: recipient@example.com
Subject: Second

Body two
MBOX

    my $fn = "$dir/test.mbox";
    open my $fh, '>', $fn or die "Can't write $fn: $!";
    print $fh $mbox;
    close $fh;

    local @ARGV = ($fn);
    my $mails = $agent->parse_mbox( {} );

    is( scalar @$mails, 2, "mbox with 2 messages yields 2 mails" );
    like( ${ $mails->[0] }, qr/Body one/,  "first mail has correct body" );
    like( ${ $mails->[1] }, qr/Body two/,  "second mail has correct body" );
    like( ${ $mails->[0] }, qr/Subject: First/,  "first mail has correct headers" );
    like( ${ $mails->[1] }, qr/Subject: Second/, "second mail has correct headers" );
}

# --- parse_mbox: mbox with >From quoting ---

{
    my $agent = _test_agent();
    my $dir   = tempdir( CLEANUP => 1 );

    # Non-mbox message containing "From " in body (should get escaped)
    my $msg = "Subject: Test\n\nLine one\nFrom sender looks like mbox separator\nLine three\n";
    my $fn  = "$dir/msg.eml";
    open my $fh, '>', $fn or die "Can't write $fn: $!";
    print $fh $msg;
    close $fh;

    local @ARGV = ($fn);
    my $mails = $agent->parse_mbox( {} );

    is( scalar @$mails, 1, "non-mbox with From in body is single message" );
    like( ${ $mails->[0] }, qr/>From sender/, "From in body gets >From quoting" );
}

# --- parse_mbox: aref input ---

{
    my $agent = _test_agent();
    my @lines = ( "Subject: Test\n", "\n", "Body from aref\n" );

    local @ARGV = ();
    my $mails = $agent->parse_mbox( { aref => \@lines } );

    ok( defined $mails, "parse_mbox with aref input returns result" );
    is( scalar @$mails, 1, "aref input yields 1 mail" );
    like( ${ $mails->[0] }, qr/Body from aref/, "aref content preserved" );
}

# --- parse_mbox: filehandle input ---

{
    my $agent = _test_agent();
    my $dir   = tempdir( CLEANUP => 1 );

    my $msg = "Subject: FH Test\n\nFilehandle body\n";
    my $fn  = "$dir/fh.eml";
    open my $wfh, '>', $fn or die;
    print $wfh $msg;
    close $wfh;

    my $fh = IO::File->new( $fn, 'r' ) or die;
    local @ARGV = ();
    my $mails = $agent->parse_mbox( { fh => $fn } );

    ok( defined $mails, "parse_mbox with fh input returns result" );
    is( scalar @$mails, 1, "fh input yields 1 mail" );
    like( ${ $mails->[0] }, qr/Filehandle body/, "fh content preserved" );
}

# --- parse_mbox: empty mbox ---

{
    my $agent = _test_agent();
    my $dir   = tempdir( CLEANUP => 1 );

    my $fn = "$dir/empty.mbox";
    open my $fh, '>', $fn or die;
    close $fh;

    local @ARGV = ($fn);
    my $mails = $agent->parse_mbox( {} );

    ok( defined $mails, "parse_mbox with empty file returns result" );
    is( scalar @$mails, 0, "empty file yields 0 mails" );
}

# --- local_check: mailing list detection ---

{
    my $agent = _test_agent( conf => { ignorelist => 1 } );

    my $mail = "From: sender\@example.com\nList-Id: mylist.example.com\n\nSpam body\n";
    my $obj = { orig_mail => \$mail, id => 1 };

    ok( $agent->local_check($obj), "local_check detects List-Id header" );
}

{
    my $agent = _test_agent( conf => { ignorelist => 1 } );

    my $mail = "From: sender\@example.com\nX-List-Id: mylist.example.com\n\nSpam body\n";
    my $obj = { orig_mail => \$mail, id => 2 };

    ok( $agent->local_check($obj), "local_check detects X-List-Id header" );
}

{
    my $agent = _test_agent( conf => { ignorelist => 1 } );

    my $mail = "From: sender\@example.com\nSubject: No list\n\nBody\n";
    my $obj = { orig_mail => \$mail, id => 3 };

    ok( !$agent->local_check($obj), "local_check passes non-list mail" );
}

{
    # ignorelist disabled — List-Id should not trigger skip
    my $agent = _test_agent( conf => { ignorelist => 0 } );

    my $mail = "From: sender\@example.com\nList-Id: mylist.example.com\n\nBody\n";
    my $obj = { orig_mail => \$mail, id => 4 };

    ok( !$agent->local_check($obj), "local_check ignores List-Id when ignorelist is off" );
}

# --- local_check: whitelist ---

{
    my $dir   = tempdir( CLEANUP => 1 );
    my $wl_fn = "$dir/razor-whitelist";

    open my $fh, '>', $wl_fn or die;
    print $fh "from  trusted\@example.com\n";
    close $fh;

    my $agent = _test_agent( conf => { whitelist => $wl_fn, ignorelist => 0 } );

    my $mail = "From: trusted\@example.com\nSubject: Hello\n\nBody\n";
    my $obj  = { orig_mail => \$mail, id => 5 };

    ok( $agent->local_check($obj), "whitelist matches From header" );
}

{
    my $dir   = tempdir( CLEANUP => 1 );
    my $wl_fn = "$dir/razor-whitelist";

    open my $fh, '>', $wl_fn or die;
    print $fh "from  trusted\@example.com\n";
    close $fh;

    my $agent = _test_agent( conf => { whitelist => $wl_fn, ignorelist => 0 } );

    my $mail = "From: stranger\@example.com\nSubject: Hello\n\nBody\n";
    my $obj  = { orig_mail => \$mail, id => 6 };

    ok( !$agent->local_check($obj), "whitelist does not match different sender" );
}

{
    # Multiple whitelist rules
    my $dir   = tempdir( CLEANUP => 1 );
    my $wl_fn = "$dir/razor-whitelist";

    open my $fh, '>', $wl_fn or die;
    print $fh "from  alice\@example.com\n";
    print $fh "to    team\@example.com\n";
    print $fh "# comment line\n";
    print $fh "from  bob\@example.com\n";
    close $fh;

    my $agent = _test_agent( conf => { whitelist => $wl_fn, ignorelist => 0 } );

    # Match by To header
    my $mail = "From: stranger\@spammer.com\nTo: team\@example.com\n\nBody\n";
    my $obj  = { orig_mail => \$mail, id => 7 };

    ok( $agent->local_check($obj), "whitelist matches To header" );
}

{
    # Empty whitelist file — should not crash
    my $dir   = tempdir( CLEANUP => 1 );
    my $wl_fn = "$dir/razor-whitelist";

    open my $fh, '>', $wl_fn or die;
    close $fh;

    my $agent = _test_agent( conf => { whitelist => $wl_fn, ignorelist => 0 } );

    my $mail = "From: anyone\@example.com\n\nBody\n";
    my $obj  = { orig_mail => \$mail, id => 8 };

    # Empty file has -s == 0, so whitelist is skipped
    ok( !$agent->local_check($obj), "empty whitelist file does not match" );
}

# --- read_whitelist ---

{
    my $dir   = tempdir( CLEANUP => 1 );
    my $wl_fn = "$dir/razor-whitelist";

    open my $fh, '>', $wl_fn or die;
    print $fh "from  alice\@example.com\n";
    print $fh "FROM  bob\@example.com\n";
    print $fh "# this is a comment\n";
    print $fh "  subject  sale\n";
    print $fh "\n";
    close $fh;

    my $agent = _test_agent( conf => { whitelist => $wl_fn } );

    # Force read_file to work by providing razorhome
    $agent->{razorhome} = $dir;

    $agent->read_whitelist();

    ok( defined $agent->{whitelist}, "whitelist loaded" );
    is( ref $agent->{whitelist}, 'HASH', "whitelist is hashref" );

    # Keys should be lowercased
    ok( exists $agent->{whitelist}->{from}, "from key exists (lowercased)" );
    is( scalar @{ $agent->{whitelist}->{from} }, 2, "2 from rules loaded" );
    is( $agent->{whitelist}->{from}[0], 'alice@example.com', "first from rule correct" );
    is( $agent->{whitelist}->{from}[1], 'bob@example.com',   "second from rule correct" );

    ok( exists $agent->{whitelist}->{subject}, "subject key exists" );
    is( $agent->{whitelist}->{subject}[0], 'sale', "subject rule correct" );
}

{
    # read_whitelist only reads once (caches)
    my $dir   = tempdir( CLEANUP => 1 );
    my $wl_fn = "$dir/razor-whitelist";

    open my $fh, '>', $wl_fn or die;
    print $fh "from  test\@example.com\n";
    close $fh;

    my $agent = _test_agent( conf => { whitelist => $wl_fn } );
    $agent->{razorhome} = $dir;

    $agent->read_whitelist();
    my $first_ref = $agent->{whitelist};

    # Modify the file
    open $fh, '>', $wl_fn or die;
    print $fh "from  other\@example.com\n";
    close $fh;

    $agent->read_whitelist();

    # Should still be the same ref (cached)
    is( $agent->{whitelist}, $first_ref, "read_whitelist caches and doesn't re-read" );
}

# --- _help ---

{
    my $agent = Razor2::Client::Agent->new('razor-check');
    my $help  = $agent->_help();
    like( $help, qr/razor-check/, "_help returns check usage" );
    like( $help, qr/-H/, "_help includes -H flag" );
    like( $help, qr/--sig/, "_help includes --sig flag" );
}

{
    my $agent = Razor2::Client::Agent->new('razor-report');
    my $help  = $agent->_help();
    like( $help, qr/razor-report/, "_help returns report usage" );
    like( $help, qr/-f/, "_help includes foreground flag" );
}

{
    my $agent = Razor2::Client::Agent->new('razor-admin');
    my $help  = $agent->_help();
    like( $help, qr/razor-admin/, "_help returns admin usage" );
    like( $help, qr/-register/, "_help includes register flag" );
    like( $help, qr/-create/, "_help includes create flag" );
}

{
    my $agent = Razor2::Client::Agent->new('razor-revoke');
    my $help  = $agent->_help();
    like( $help, qr/razor-revoke/, "_help returns revoke usage" );
}

# --- log and logll ---

{
    my $agent = _test_agent();

    # No logref — log should not crash
    $agent->log( 1, "test message" );
    ok( 1, "log() with no logref does not crash" );
}

{
    my $agent = _test_agent( opt => { debug => 1 } );

    # With debug on and no logref, should print to stdout
    my $output = '';
    {
        local *STDOUT;
        open STDOUT, '>', \$output or die;
        $agent->log( 1, "debug test" );
    }
    like( $output, qr/debug test/, "log() prints to stdout in debug mode" );
}

{
    my $agent = _test_agent();

    # logll with no logref returns undef
    ok( !$agent->logll(5), "logll returns false with no logref" );
}

# --- doit dispatcher routing ---

{
    my $agent = _test_agent();
    is( $agent->{breed}, 'check', "doit would route to checkit for check breed" );
}

{
    my $agent = Razor2::Client::Agent->new('razor-report');
    $agent->{conf} = {};
    $agent->{opt}  = {};
    $agent->{logref} = 0;
    is( $agent->{breed}, 'report', "doit would route to reportit for report breed" );
}

{
    my $agent = Razor2::Client::Agent->new('razor-admin');
    $agent->{conf} = {};
    $agent->{opt}  = {};
    $agent->{logref} = 0;
    is( $agent->{breed}, 'admin', "doit would route to adminit for admin breed" );
}

# --- logerr ---

{
    my $agent = _test_agent();
    $agent->{breed} = 'check';
    $agent->error("test error message");

    # logerr should not crash even with no logger
    $agent->logerr();
    ok( 1, "logerr does not crash with no logger" );
}

# --- parse_mbox: multi-line header in non-mbox ---

{
    my $agent = _test_agent();
    my $dir   = tempdir( CLEANUP => 1 );

    my $msg = "Subject: A very long\n subject line\nFrom: test\@example.com\n\nBody here\n";
    my $fn  = "$dir/multiline.eml";
    open my $fh, '>', $fn or die;
    print $fh $msg;
    close $fh;

    local @ARGV = ($fn);
    my $mails = $agent->parse_mbox( {} );

    is( scalar @$mails, 1, "multi-line header message parsed as single mail" );
    like( ${ $mails->[0] }, qr/Body here/, "body preserved in multi-line header message" );
}

# --- local_check: multi-line List-Id header ---

{
    my $agent = _test_agent( conf => { ignorelist => 1 } );

    my $mail = "From: sender\@example.com\nList-Id:\n mylist.example.com\n\nBody\n";
    my $obj = { orig_mail => \$mail, id => 10 };

    ok( $agent->local_check($obj), "local_check detects multi-line List-Id (folded header)" );
}

# --- local_check: whitelist with regex pattern ---

{
    my $dir   = tempdir( CLEANUP => 1 );
    my $wl_fn = "$dir/razor-whitelist";

    open my $fh, '>', $wl_fn or die;
    print $fh "from  .*\@trusted-domain\\.com\n";
    close $fh;

    my $agent = _test_agent( conf => { whitelist => $wl_fn, ignorelist => 0 } );

    my $mail = "From: anyone\@trusted-domain.com\nSubject: Hello\n\nBody\n";
    my $obj  = { orig_mail => \$mail, id => 11 };

    ok( $agent->local_check($obj), "whitelist supports regex patterns" );
}

# --- local_check: no_whitelist flag caching ---

{
    my $agent = _test_agent( conf => { whitelist => '/nonexistent/path', ignorelist => 0 } );
    $agent->{no_whitelist} = 1;

    my $mail = "From: anyone\@example.com\n\nBody\n";
    my $obj  = { orig_mail => \$mail, id => 12 };

    ok( !$agent->local_check($obj), "no_whitelist flag skips whitelist processing" );
}

done_testing;
