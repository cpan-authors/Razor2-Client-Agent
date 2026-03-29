[![testsuite](https://github.com/cpan-authors/Razor2-Client-Agent/actions/workflows/testsuite.yml/badge.svg)](https://github.com/cpan-authors/Razor2-Client-Agent/actions/workflows/testsuite.yml)

# Razor2-Client-Agent

Vipul's Razor v2 — a distributed, collaborative, spam detection and
filtering network agent.

## Description

Razor establishes a distributed and constantly updating catalogue of spam
in propagation that is consulted by email clients to filter out known spam.
Detection is done with statistical and randomized signatures that
efficiently spot mutating spam content. User input is validated through
reputation assignments based on consensus on report and revoke assertions
which in turn is used for computing confidence values associated with
individual signatures.

## Installation

From CPAN:

    cpanm Razor2::Client::Agent

From source:

    perl Makefile.PL
    make
    make test
    make install

After installation, set up your Razor home directory and register:

    razor-admin -create
    razor-admin -register

## Usage

**Check mail for spam:**

    cat message.eml | razor-check
    razor-check ./message.eml

`razor-check` exits with `0` if the mail is spam, `1` if not.

**Report spam:**

    cat spam.eml | razor-report

**Revoke a false positive:**

    cat ham.eml | razor-revoke

For integration with mail processors like SpamAssassin or procmail,
see the individual tool man pages: `razor-check(1)`, `razor-report(1)`,
`razor-revoke(1)`, `razor-admin(1)`.

## Configuration

The configuration file is `razor-agent.conf`, located in your Razor
home directory (typically `~/.razor/`). Create or regenerate it with:

    razor-admin -create

Key settings:

| Setting              | Default     | Description                        |
|----------------------|-------------|------------------------------------|
| `debuglevel`         | `3`         | Log verbosity (0-20)               |
| `logfile`            | `razor-agent.log` | Log destination (`syslog`, `stderr`, or path) |
| `min_cf`             | `ac`        | Minimum confidence filter (`ac` = server-recommended) |
| `report_headers`     | `1`         | Include headers in reports         |
| `turn_off_discovery` | `0`        | Disable server discovery           |
| `whitelist`          | `razor-whitelist` | Whitelist file                |

See `razor-agent.conf(5)` for full documentation.

## Key Features

- **Ephemeral Signatures** — short-lived signatures based on collaboratively
  computed random numbers, making the hashing scheme a moving target
- **Multiple Engines** — pluggable filtration engines (VR4 Ephemeral, VR8 SHA)
- **Preprocessors** — Base64, Quoted-Printable, and HTML decoding to hash
  the content recipients actually see
- **Truth Evaluation System (TeS)** — reputation-based trust and confidence
  scoring to minimize false positives
- **Revocation** — users can revoke incorrectly classified messages
- **Pipelining** — persistent connections to reduce latency

## Requirements

- Perl 5.10 or later
- Core modules: Digest::SHA, MIME::Base64, URI::Escape, File::Copy, File::Spec
- IO::Socket::IP
- C compiler (for the XS HTML preprocessor)

## Documentation

- `razor-check(1)` — check mail against the Razor catalogue
- `razor-report(1)` — report spam to the Razor catalogue
- `razor-revoke(1)` — revoke a previous spam report
- `razor-admin(1)` — admin tool for registration and server discovery
- `razor-agent.conf(5)` — configuration file format
- `razor-agents(1)` — overview of all Razor agents
- `razor-whitelist(5)` — whitelist file format

## License

This is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. See [perlartistic](https://perldoc.perl.org/perlartistic)
and [perlgpl](https://perldoc.perl.org/perlgpl).
