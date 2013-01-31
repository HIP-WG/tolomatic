package Bio::PhyloTastic::Pruner::Runner::Mock;
use strict;
use warnings;
use Bio::Phylo::Factory;
use Bio::Phylo::Util::Logger;
use Bio::PhyloTastic::Pruner::Util;
use Bio::PhyloTastic::Pruner::CONSTANT qw(TREEID TAXALIST TAXONID);

# fetch the constants
my $treeid   = TREEID;
my $taxalist = TAXALIST;
my $taxonid  = TAXONID;

# instantiate helper objects
my $util = Bio::PhyloTastic::Pruner::Util->new;
my $fact = Bio::Phylo::Factory->new;
my $log  = Bio::Phylo::Util::Logger->new;

sub run {
	my $self = shift;
	my %args = @_;
	
	# instantiate containers
	my $tree    = $fact->create_tree;
	my $forest  = $fact->create_forest;
	my $project = $fact->create_project;
	$forest->insert($tree);
	$project->insert($forest);
	
	# fetch the tree uri
	my $tree_uri = $args{$treeid};
	
	# fetch the IDs from the JSON data structure
	my @ids = map { $_->{$taxonid} } @{ $args{$taxalist} };
	
	# iterate over ids
	my %seen;
	for my $id ( @ids ) {
		$log->info("processing id $id");
		
		# fetch the tip to root path for the focal node
		my ( $dir, $file ) = $util->taxon_dir($tree_uri,$id);
		my @path = $util->read_taxon_file( "$dir/$file" );
		$log->info("path is @path");
		
		# traverse path
		for my $i ( 0 .. $#path ) {
			
			# path fragments are now tuples of label:branch_length
			my ( $label, $length ) = split /:/, $path[$i];
			
			# can see the same label multiple times, coming from different tips
			if ( not $seen{$label} ) {
				
				# instantiate new node, insert in tree
				$seen{$label} = $fact->create_node(
					'-name'          => $label,
					'-branch_length' => $length,
				);
				$tree->insert($seen{$label});
			}
			
			# path fragment is interior, so could have multiple children
			if ( $i > 0 ) {
				my ($child) = split /:/, $path[$i-1];
				
				# do this only once
				if ( not $seen{$child}->get_parent ) {
					$seen{$child}->set_parent($seen{$label});
				}
			}
		}
	}
	$tree->remove_unbranched_internals;
	my $taxa = $forest->make_taxa;
	$project->insert($taxa);
	return $project;
}


1;