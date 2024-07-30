#!/usr/bin/env perl

# get-forcematch-sqlids.pl

use warnings;
use strict;
use Data::Dumper;

use lib '/usr/share/mrtools/perlmods/';

use ForceMatch;

my %reverseMatched = %{ForceMatch::getRevHash()};

my $forceMatchedID = $ARGV[0];

die "force match signature required\n" unless defined($forceMatchedID);

if ( exists($reverseMatched{$forceMatchedID}) ) {
	print join("\n", @{$reverseMatched{$forceMatchedID}}) . "\n";
} else {
	print "no data found for $forceMatchedID\n";
}
