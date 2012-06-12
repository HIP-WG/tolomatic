#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Bio::Phylo::IO 'parse';
use Bio::Phylo::Util::CONSTANT ':objecttypes';

# process command line arguments
my $infile;
my $start = 1;
GetOptions( 'infile=s' => \$infile, 'start=i' => $start );

# parse tree
my ($tree) = @{ parse(
	'-format' => 'newick',
	'-file'   => $infile,
	'-as_project' => 1,
)->get_items(_TREE_) };

my $index = $start;
$tree->visit_depth_first(
	'-pre' => sub {
		my $node = shift;
		my ( $label, $left, $right, $support, $parent );
		
		# compute pre-order index
		$node->set_generic( 'left' => $left = $index++ );
		
		# parse out post-order index
		my $name = $node->get_name;
		if ( $name =~ /\.(\d+)$/ ) {
			$right = $1;
		}
		
		# parse out support value and label on internal nodes
		if ( $node->is_internal ) {
			if ( $name =~ /^(\d+)\.\d+$/ ) {
				$support = $1;
			}
			elsif ( $name =~ /^'(\d+):(.+?)'/ ) {
				( $support, $label ) = ( $1, $2 );
			}
			elsif ( $name =~ /^(.+)\.\d+$/ ) {
				$label = $1;
			}
		}
		else {
			if ( $name =~ /^(\d+)\.\d+$/ ) {
				$label = $1;
			}
		}
		
		# process the root
		if ( $node->is_root ) {
			$label = $name;
		}
		else {
			$parent = $node->get_parent->get_generic('left');
		}
		
		print join( ',', $left, $right, $parent, $label, $support, $infile ), "\n";	
	}
);
		