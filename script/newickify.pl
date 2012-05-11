#!/usr/bin/perl
use strict;
use warnings;
use Bio::Phylo::Factory;
use Data::Dumper;

# build ancestor paths for all tips
my %ancestors;
while(<>) {
	chomp;
	my @line = split /\t/, $_;
	my @taxa = split /\|/, $line[0];
	my ( $ancestor, $ntax ) = split /,/, $line[1];
	
	# by now these aren't sorted in post-order
	for my $taxon ( @taxa ) {
		$ancestors{$taxon} = [] if not $ancestors{$taxon};
		push @{ $ancestors{$taxon} }, $ancestor;
	}
}

# instantiate factory and tree
my $fac = Bio::Phylo::Factory->new;
my $tree = $fac->create_tree;

# build up node relations
my %node;
for my $taxon ( keys %ancestors ) {
	my $child = $fac->create_node( '-name' => $taxon );
	$tree->insert($child);
	
	# break once we've coalesced with a previously seen lineage
	ANCESTOR: for my $ancestor ( sort { $a <=> $b } @{ $ancestors{$taxon} } ) {
		my $parent = $node{$ancestor};
		if ( $parent ) {
			$parent->set_child( $child );
			last ANCESTOR;
		}
		$parent = $node{$ancestor} = $fac->create_node( '-name' => $ancestor );
		$parent->set_child($child);
		$tree->insert($parent);
		$child = $parent;
	}
}

print $tree->to_newick;
