#!/usr/bin/perl
use strict;
use warnings;

while(<>) {
	warn $_;
}

my ( $key, $infile ) = @ARGV;
my @fields;
{
	open my $fh, '<', $infile or die $!;
	my @lines = <$fh>;
	close $fh;
	@fields = split /\t/, $lines[0];
}
if ( $key eq $fields[0] ) {
	for my $i ( 1 .. $#fields ) {
		print "UniqValueCount:", $fields[$i-1], "\t", $fields[$i], "\n";
	}
}