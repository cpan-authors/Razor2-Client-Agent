#!perl

use strict;
use warnings;

use Test::More;
use MIME::Base64 ();

use_ok('Razor2::Preproc::enBase64');

# --- Construction ---

{
    my $enc = Razor2::Preproc::enBase64->new;
    isa_ok( $enc, 'Razor2::Preproc::enBase64' );
}

# --- isit() binary detection ---
# Note: isit() checks for the FIRST byte matching [\x00-\x1f|\x7f-\xff].
# If that first match is \r, \n, or \t, it returns false even if binary
# bytes exist later. Tests use content without leading whitespace control chars.

{
    my $enc = Razor2::Preproc::enBase64->new;

    # Binary content with null byte (before any \r\n\t)
    my $text = "\x00Hello World";
    ok( $enc->isit( \$text ), "isit() detects null byte as binary" );
}

{
    my $enc = Razor2::Preproc::enBase64->new;

    # Binary content with high-bit byte
    my $text = "\x80Hello World";
    ok( $enc->isit( \$text ), "isit() detects high-bit byte as binary" );
}

{
    my $enc = Razor2::Preproc::enBase64->new;

    # Control characters (except \r, \n, \t)
    my $text = "\x01Hello World";
    ok( $enc->isit( \$text ), "isit() detects control char as binary" );
}

{
    my $enc = Razor2::Preproc::enBase64->new;

    # Plain ASCII text should NOT be binary
    my $text = "Hello World plain text";
    ok( !$enc->isit( \$text ), "isit() rejects plain ASCII text" );
}

{
    my $enc = Razor2::Preproc::enBase64->new;

    # Whitespace characters (\r, \n, \t) as first control char — NOT binary
    my $text = "Hello\nWorld";
    ok( !$enc->isit( \$text ), "isit() treats \\n as non-binary" );
}

{
    my $enc = Razor2::Preproc::enBase64->new;

    # DEL character (0x7f) is binary
    my $text = "\x7fHello";
    ok( $enc->isit( \$text ), "isit() detects DEL (0x7f) as binary" );
}

{
    my $enc = Razor2::Preproc::enBase64->new;

    # 0xFF byte is binary
    my $text = "\xffHello";
    ok( $enc->isit( \$text ), "isit() detects 0xFF as binary" );
}

{
    my $enc = Razor2::Preproc::enBase64->new;

    # Binary byte AFTER newline is missed (known limitation)
    my $text = "Hello\n\x00World";
    ok( !$enc->isit( \$text ),
        "isit() misses binary after \\n (first match is \\n, exits)" );
}

# --- doit() base64 encoding ---

{
    my $enc = Razor2::Preproc::enBase64->new;

    # Encode simple binary content
    my $original = "Hello\x00World";
    my $text = $original;
    $enc->doit( \$text );

    like( $text, qr/^Content-Transfer-Encoding: base64\n\n/,
        "doit() prepends base64 content-transfer-encoding header" );

    # Extract the encoded body and decode it
    my ($encoded_body) = $text =~ /^Content-Transfer-Encoding: base64\n\n(.+)$/s;
    $encoded_body =~ s/\n//g;  # remove line wrapping
    my $decoded = MIME::Base64::decode_base64($encoded_body);
    is( $decoded, $original, "doit() output can be round-tripped through MIME::Base64" );
}

{
    my $enc = Razor2::Preproc::enBase64->new;

    # Line wrapping at 76 chars
    my $text = "A" x 200;
    $enc->doit( \$text );

    my ($body) = $text =~ /^Content-Transfer-Encoding: base64\n\n(.+)$/s;
    my @lines = split /\n/, $body;
    for my $line (@lines) {
        ok( length($line) <= 76, "line length <= 76: " . length($line) );
    }
}

{
    my $enc = Razor2::Preproc::enBase64->new;

    # Padding: 1 byte input (needs == padding)
    my $text = "X";
    $enc->doit( \$text );
    my ($body) = $text =~ /\n\n(.+)$/s;
    $body =~ s/\n//g;
    like( $body, qr/==$/, "doit() adds == padding for 1-byte input" );
}

{
    my $enc = Razor2::Preproc::enBase64->new;

    # Padding: 2 byte input (needs = padding)
    my $text = "XY";
    $enc->doit( \$text );
    my ($body) = $text =~ /\n\n(.+)$/s;
    $body =~ s/\n//g;
    like( $body, qr/[^=]=$/, "doit() adds = padding for 2-byte input" );
}

{
    my $enc = Razor2::Preproc::enBase64->new;

    # Padding: 3 byte input (no padding)
    my $text = "XYZ";
    $enc->doit( \$text );
    my ($body) = $text =~ /\n\n(.+)$/s;
    $body =~ s/\n//g;
    unlike( $body, qr/=$/, "doit() adds no padding for 3-byte input" );
}

{
    my $enc = Razor2::Preproc::enBase64->new;

    # Empty input
    my $text = "";
    $enc->doit( \$text );
    like( $text, qr/^Content-Transfer-Encoding: base64\n\n/,
        "doit() handles empty input" );
}

{
    my $enc = Razor2::Preproc::enBase64->new;

    # All high-bit bytes
    my $text = join '', map { chr($_) } 128..255;
    my $original = $text;
    $enc->doit( \$text );

    my ($encoded_body) = $text =~ /^Content-Transfer-Encoding: base64\n\n(.+)$/s;
    $encoded_body =~ s/\n//g;
    my $decoded = MIME::Base64::decode_base64($encoded_body);
    is( $decoded, $original, "doit() correctly encodes all high-bit bytes" );
}

done_testing;
