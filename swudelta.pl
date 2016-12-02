#! /usr/bin/perl

use strict;
use warnings;

use File::Basename qw/basename/;
use File::Temp qw/tempdir/;

if (@ARGV < 2 or @ARGV > 3) {
    print STDERR "usage: $0 OLD NEW [DELTA]\n";
    exit 1;
}

my $swu_a = $ARGV[0];
my $swu_b = $ARGV[1];
my $swu_d = $ARGV[2];

-e $swu_a || die "$swu_a: $!";
-e $swu_b || die "$swu_b: $!";

sub get_version {
    my ($file) = @_;
    my $version;

    open my $swd, '<', $file or return;
    while (<>) {
        if (/venus-version = "(.*)"/) {
            $version = $1;
            last;
        }
    }
    close $swd;

    return $version;
}

sub xdelta {
    my ($a, $b, $d) = @_;
    system "xdelta3", "-qe", "-s", $a, $b, $d and die "xdelta3 error";
}

my $tmp = tempdir(CLEANUP => 1) || die "tempdir: $!";

my $a = "$tmp/a";
my $b = "$tmp/b";
my $d = "$tmp/d";

mkdir $a || die "mkdir: $a: $!";
mkdir $b || die "mkdir: $b: $!";
mkdir $d || die "mkdir: $d: $!";

system qq{cpio -i --quiet -D "$a" <"$swu_a"} and die "$swu_a: cpio error";
system qq{cpio -i --quiet -D "$b" <"$swu_b"} and die "$swu_b: cpio error";

my $version_a = get_version "$a/sw-description" or die;
my $version_b = get_version "$b/sw-description" or die;

if (not $swu_d) {
    ($swu_d = $swu_b) =~ s/(-[0-9]+-v[0-9.~]+)?\.swu$//;
    my $v = $version_a . '-' . $version_b;
    $v =~ s/ /-/g;
    $swu_d .= "-$v.swu";
}

my @files = ('sw-description');
my $is_delta = 0;

open my $swb, '<', "$b/sw-description" || die "$b/sw-description: $!";
open my $swd, '>', "$d/sw-description" || die "$d/sw-description: $!";

while (<$swb>) {
    # skip bootloader section
    if (/^\s*bootloader:/) {
        my $bl = 0;
        do {
            $bl++ while /{/g;
            $bl-- while /}/g;
            $_ = <$swb>;
        } while ($bl);
    }

    if (/^\s*images:/) {
        my $bl = 0;
        do {
            $bl++ while /\(/g;
            $bl-- while /\)/g;

            $is_delta = 0 if /}/;

            if (/(\s*)filename\s*=\s*"(.*)"/) {
                my $indent = $1;
                my $file = $2;
                if ($file =~ /\.ext4\.gz$/ and -e "$a/$file") {
                    my $delta = $file;
                    $delta =~ s/(\.gz$)$/.vcdiff/;
                    if (not -e "$d/$delta") {
                        xdelta "$a/$file", "$b/$file", "$d/$delta";
                        push @files, $delta;
                    }
                    $is_delta = 1;
                    print $swd qq{${indent}filename = "$delta";\n};
                    print $swd qq{${indent}type = "pipe";\n};
                    print $swd qq{${indent}data = "apply-delta.sh";\n};
                } else {
                    if (not -e "$d/$file") {
                        link "$b/$file", "$d/$file" or die "$d/$file: $!";
                        push @files, $file;
                    }
                    print $swd $_;
                }
            } elsif (/^\s*compressed/ and $is_delta) {
                # skip
            } else {
                print $swd $_;
            }

            $_ = <$swb>;
        } while ($bl);
    }

    print $swd $_;

    if (/(\s*)venus-version/) {
        print $swd qq{${1}venus-base-version = "$version_a";\n};
    }
}

close $swb;
close $swd;

open my $cpio, '|-', qq{cpio -o --quiet -H crc -D "$d" >"$swu_d"}
    or die "cpio: $!";
print $cpio "$_\n" for @files;
close $cpio;
