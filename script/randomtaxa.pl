#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;

# process command line arguments
my ( $infile, $ntax, $percentage );
GetOptions(
	'infile=s'     => \$infile,
	'ntax=i'       => \$ntax,
	'percentage=i' => \$percentage,
);

# verify parameters
if ( not ( $ntax xor $percentage ) and not $infile ) {
	die "Need -infile and -ntax or -percentage arguments!";
}

# read taxa file
my @taxa;
{
	open my $fh, '<', $infile or die $!;
	while(<$fh>) {
		chomp;
		next if /^\s*$/;
		my @fields = split /\t/, $_;
		my $taxon = pop @fields;
		push @taxa, $taxon;
	}
	close $fh;
}

# translate percentage to absolute number
if ( $percentage ) {
	$ntax = int( scalar(@taxa) * $percentage / 100 ) + 1;
}

# sample without replacement
my %seen;
while(scalar(keys %seen) < $ntax) {
	$seen{ int rand $ntax } = 1;
}
print join "\n", @taxa[keys %seen];