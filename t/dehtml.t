#!perl

use strict;
use warnings;

use Test::More;

use_ok('Razor2::Preproc::deHTML');

# --- Construction ---

{
    my $d = Razor2::Preproc::deHTML->new;
    isa_ok( $d, 'Razor2::Preproc::deHTML' );
    ok( exists $d->{html_tags}, "html_tags hash is populated" );
    is( $d->{html_tags}{lt},   '<',       "lt entity maps to <" );
    is( $d->{html_tags}{amp},  '&',       "amp entity maps to &" );
    is( $d->{html_tags}{nbsp}, ' ',       "nbsp entity maps to space" );
    is( $d->{html_tags}{yuml}, chr(255),  "yuml entity maps to chr(255)" );
}

# --- isit() detection ---

{
    my $d = Razor2::Preproc::deHTML->new;

    # Detects <HTML> tag in body
    my $msg = "Subject: test\n\n<HTML><BODY>Hello</BODY></HTML>";
    ok( $d->isit( \$msg ), "isit() detects <HTML> tag" );

    # Detects <BODY tag
    $msg = "Subject: test\n\n<BODY bgcolor='white'>Hello</BODY>";
    ok( $d->isit( \$msg ), "isit() detects <BODY tag" );

    # Detects <FONT tag
    $msg = "Subject: test\n\n<FONT size=3>Hello</FONT>";
    ok( $d->isit( \$msg ), "isit() detects <FONT tag" );

    # Detects <A HREF tag
    $msg = "Subject: test\n\n<A HREF='http://example.com'>link</A>";
    ok( $d->isit( \$msg ), "isit() detects <A HREF tag" );

    # Detects text/html content-type header
    $msg = "Content-Type: text/html\n\nPlain body";
    ok( $d->isit( \$msg ), "isit() detects text/html in header" );

    # Case insensitive detection
    $msg = "content-type: text/html; charset=utf-8\n\nPlain body";
    ok( $d->isit( \$msg ), "isit() is case insensitive for header" );

    $msg = "Subject: test\n\n<html><body>Hello</body></html>";
    ok( $d->isit( \$msg ), "isit() is case insensitive for tags" );

    # Rejects plain text
    $msg = "Subject: test\n\nJust plain text";
    ok( !$d->isit( \$msg ), "isit() rejects plain text" );

    # Rejects when no body
    $msg = "Subject: test only headers";
    ok( !$d->isit( \$msg ), "isit() returns 0 when no body" );
}

# --- doit() HTML stripping ---

{
    my $d = Razor2::Preproc::deHTML->new;

    # Basic tag stripping
    my $text = "Subject: test\n\n<b>bold</b> and <i>italic</i>";
    $d->doit( \$text );
    like( $text, qr/bold and italic/, "doit() strips basic tags" );
    unlike( $text, qr/<b>/, "doit() removes <b> tag" );
}

{
    my $d = Razor2::Preproc::deHTML->new;

    # Preserves headers
    my $text = "Subject: test\nFrom: sender\n\n<p>paragraph</p>";
    $d->doit( \$text );
    like( $text, qr/^Subject: test\nFrom: sender\n\n/, "doit() preserves headers" );
    like( $text, qr/paragraph/, "doit() keeps text content" );
}

{
    my $d = Razor2::Preproc::deHTML->new;

    # Entity decoding — named entities
    my $text = "Subject: test\n\n&lt;hello&gt; &amp; &quot;world&quot;";
    $d->doit( \$text );
    like( $text, qr/<hello>/, "doit() decodes &lt; and &gt;" );
    like( $text, qr/& "world"/, "doit() decodes &amp; and &quot;" );
}

{
    my $d = Razor2::Preproc::deHTML->new;

    # Entity with semicolons
    my $text = "Subject: test\n\n&lt;tag&gt;";
    $d->doit( \$text );
    like( $text, qr/<tag>/, "doit() handles entities with semicolons" );
}

{
    my $d = Razor2::Preproc::deHTML->new;

    # Entity without semicolons (compat mode) — needs non-alpha terminator
    my $text = "Subject: test\n\n&lt hello &gt end";
    $d->doit( \$text );
    like( $text, qr/< hello/, "doit() decodes entity without trailing semicolon" );
}

{
    my $d = Razor2::Preproc::deHTML->new;

    # Nested tags
    my $text = "Subject: test\n\n<div><span>inner</span></div>";
    $d->doit( \$text );
    like( $text, qr/inner/, "doit() handles nested tags" );
    unlike( $text, qr/<div>/, "doit() strips outer tag" );
    unlike( $text, qr/<span>/, "doit() strips inner tag" );
}

{
    my $d = Razor2::Preproc::deHTML->new;

    # Tag with attributes
    my $text = "Subject: test\n\n<a href=\"http://example.com\" class='link'>click</a>";
    $d->doit( \$text );
    like( $text, qr/click/, "doit() preserves text inside tagged element" );
    unlike( $text, qr/href/, "doit() removes tag attributes" );
}

{
    my $d = Razor2::Preproc::deHTML->new;

    # SGML comment stripping
    my $text = "Subject: test\n\n<HTML>before<!-- comment -->after</HTML>";
    $d->doit( \$text );
    like( $text, qr/beforeafter/, "doit() strips SGML comments" );
    unlike( $text, qr/comment/, "doit() removes comment content" );
}

{
    my $d = Razor2::Preproc::deHTML->new;

    # Quoted strings inside tags
    my $text = "Subject: test\n\n<img src=\"photo.jpg\" alt=\"A >B test\">";
    $d->doit( \$text );
    unlike( $text, qr/photo\.jpg/, "doit() handles quoted > inside attributes" );
}

{
    my $d = Razor2::Preproc::deHTML->new;

    # Single-quoted strings inside tags
    my $text = "Subject: test\n\n<div class='big>thing'>content</div>";
    $d->doit( \$text );
    like( $text, qr/content/, "doit() handles single-quoted > inside attributes" );
}

{
    my $d = Razor2::Preproc::deHTML->new;

    # Ampersand that is not an entity
    my $text = "Subject: test\n\nAT&T and R&D";
    $d->doit( \$text );
    like( $text, qr/AT&T/, "doit() preserves bare & when not an entity" );
}

{
    my $d = Razor2::Preproc::deHTML->new;

    # High-ASCII entities (Latin-1 supplement)
    my $text = "Subject: test\n\n&copy; &reg; &micro;";
    $d->doit( \$text );
    my $copy  = chr(169);
    my $reg   = chr(174);
    my $micro = chr(181);
    like( $text, qr/\Q$copy\E/,  "doit() decodes &copy;" );
    like( $text, qr/\Q$reg\E/,   "doit() decodes &reg;" );
    like( $text, qr/\Q$micro\E/, "doit() decodes &micro;" );
}

{
    my $d = Razor2::Preproc::deHTML->new;

    # Hyphen outside tags preserved
    my $text = "Subject: test\n\nwell-known fact";
    $d->doit( \$text );
    like( $text, qr/well-known/, "doit() preserves hyphens in body text" );
}

{
    my $d = Razor2::Preproc::deHTML->new;

    # Empty body
    my $text = "Subject: test\n\n";
    $d->doit( \$text );
    like( $text, qr/^Subject: test\n\n$/, "doit() handles empty body" );
}

{
    my $d = Razor2::Preproc::deHTML->new;

    # Complex real-world HTML email body
    my $text = "Content-Type: text/html\n\n<HTML><HEAD><TITLE>Spam</TITLE></HEAD><BODY><P>Buy <B>cheap</B> stuff &amp; more!</P></BODY></HTML>";
    $d->doit( \$text );
    like( $text, qr/Buy cheap stuff & more!/, "doit() processes realistic HTML email" );
    unlike( $text, qr/<HTML>/, "doit() strips all tags from real email" );
    # Note: deHTML only strips tags, not content between them — TITLE text is preserved
    like( $text, qr/Spam/, "doit() preserves text content between tags" );
}

{
    my $d = Razor2::Preproc::deHTML->new;

    # nbsp entity (common in spam)
    my $text = "Subject: test\n\nword&nbsp;word";
    $d->doit( \$text );
    like( $text, qr/word word/, "doit() decodes &nbsp; to space" );
}

# --- html_xlat() unit tests ---

{
    my $d = Razor2::Preproc::deHTML->new;

    # Non-alpha at start returns 0
    my @chars = split //, "123abc";
    is( $d->html_xlat( \@chars, 0 ), 0, "html_xlat() returns 0 for non-alpha start" );
}

{
    my $d = Razor2::Preproc::deHTML->new;

    # Known entity without semicolon
    my @chars = split //, "lt rest";
    my ( $len, $val ) = $d->html_xlat( \@chars, 0 );
    is( $len, 2,   "html_xlat() returns length 2 for 'lt'" );
    is( $val, '<',  "html_xlat() returns '<' for 'lt'" );
}

{
    my $d = Razor2::Preproc::deHTML->new;

    # Known entity with semicolon
    my @chars = split //, "amp;rest";
    my ( $len, $val ) = $d->html_xlat( \@chars, 0 );
    is( $len, 4,   "html_xlat() returns length 4 for 'amp;' (includes semicolon)" );
    is( $val, '&',  "html_xlat() returns '&' for 'amp'" );
}

{
    my $d = Razor2::Preproc::deHTML->new;

    # Unknown entity returns 0
    my @chars = split //, "xyz;rest";
    is( $d->html_xlat( \@chars, 0 ), 0, "html_xlat() returns 0 for unknown entity" );
}

{
    my $d = Razor2::Preproc::deHTML->new;

    # Entity at end of array (boundary test)
    my @chars = split //, "gt";
    my ( $len, $val ) = $d->html_xlat( \@chars, 0 );
    is( $len, 2,   "html_xlat() handles entity at end of array" );
    is( $val, '>',  "html_xlat() decodes entity at array boundary" );
}

# --- html_xlat_old() tests ---

{
    my $d = Razor2::Preproc::deHTML->new;

    # Non-alpha returns 0
    my @chars = split //, "123";
    is( $d->html_xlat_old( \@chars, 0 ), 0, "html_xlat_old() returns 0 for non-alpha" );
}

{
    my $d = Razor2::Preproc::deHTML->new;

    # Known entity
    my @chars = split //, "lt;rest";
    my ( $len, $val ) = $d->html_xlat_old( \@chars, 0 );
    is( $len, 3,   "html_xlat_old() returns length including semicolon" );
    is( $val, '<',  "html_xlat_old() returns '<' for lt" );
}

done_testing;
