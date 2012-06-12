#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;

# process command line options
my $infile;
my $start = 1;
GetOptions( 'infile=s' => \$infile, 'start=i' => \$start );

my $index = $start;
open my $fh, '<', $infile or die $!;
while(<$fh>){
	chomp;
	for my $word ( split /\)/, $_ ) {
		$word =~ s/'.+?'//g;
		if ( $word !~ /;/ ) {
			print $word, ')', $index++;
		}
		else {
			print ';';
		}
	}
}