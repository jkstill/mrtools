#!/usr/bin/env perl

# force-match-gen.pl

use warnings;
use strict;
use Data::Dumper;

use lib './';

use ForceMatch;

my %forceMatched = %{ForceMatch::getHash()};

my %reverseMatched = ();

foreach my $sqlid ( keys %forceMatched ) {
	#print "sqlid: $sqlid\n";
	push @{$reverseMatched{$forceMatched{$sqlid}}}, $sqlid;
}

#print Dumper(\%reverseMatched);

my $file='ForceMatch.pm';

open (my $fh, '>>' , $file ) || die "could not open $file for append - $!\n";

print $fh "\n" . q{sub getRevHash { return \%reverseMatched; };} . "\n\n";

print $fh "our %reverseMatched = (\n";

foreach my $forceMatchedID ( keys %reverseMatched) {

	print $fh "\t'$forceMatchedID' => [\n";

	#my @s = @{$reverseMatched{$forceMatchedID]
	foreach my $sqlid ( @{$reverseMatched{$forceMatchedID}} ) {
		print $fh  "\t\t'$sqlid',\n";
	}

	print $fh "\t],\n";

}

print $fh ");\n\n";
print $fh "1;\n\n";
