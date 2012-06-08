#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Bio::Phylo::Factory;
use Bio::Phylo::IO 'unparse';
use Bio::Phylo::Util::CONSTANT ':namespaces';

# process command line arguments
my $infile;
my $format = 'newick';
my %defines;
GetOptions(
	'infile=s' => \$infile,
	'format=s' => \$format,
	'define=s' => \%defines,
);

# build ancestor paths for all tips
my %ancestors;
{
	open my $fh, '<', $infile or die $!;
	while(<$fh>) {
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

# remove unbranched internals
$tree->remove_unbranched_internals;

# populate wrapper objects
my $forest  = $fac->create_forest;
$forest->insert($tree);
my $taxa = $forest->make_taxa;
my $project = $fac->create_project;
$project->insert($taxa);
$project->insert($forest);

# copy scientific names over to phyloxml slots
if ( 'phyloxml' eq lc $format ) {
	$taxa->visit(sub{
		my $taxon = shift;
		if ( my $name = $taxon->get_name ) {
			my $meta = $fac->create_meta(
				'-namespaces' => { 'pxml' => _NS_PHYLOXML_ },
				'-triple'     => { 'pxml:scientific_name' => $name },
			);
			$taxon->add_meta($meta);
		}
	});
}

# attach provenance metadata
my $ns = 'http://phylotastic.org/terms#';
for my $key ( keys %defines ) {
	$project->add_meta(
		$fac->create_meta(
			'-namespaces' => { 'pt' => $ns },
			'-triple'     => { "pt:$key" => $defines{$key} }
		)
	);
}

print unparse(
	'-phylo'  => $project,
	'-format' => $format,
);
