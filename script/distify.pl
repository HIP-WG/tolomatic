#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Bio::Phylo::IO 'parse';

# process command line arguments
my ( $infile );
GetOptions(
	'infile=s' => \$infile,
);

# parse single tree
my $tree = parse(
	'-format' => 'newick',
	'-file'   => $infile,
)->first;

# we index the nodes in pre- and post-order, "left" and "right"
my $index = 0;
my $md5;
$tree->visit_depth_first(
	'-pre' => sub {
		my $node = shift;
		
		# this must be the root
		$md5 = $node->get_name unless $md5;
		$node->set_generic( 'l' => $index++ );
	},
	'-post' => sub {
		my $node = shift;
		$node->set_generic( 'r' => $index++ );
	},
);

# now print out all tip-to-root paths
$tree->visit_depth_first(
	'-pre' => sub {
		my $node = shift;
		if ( $node->is_terminal ) {

			# a terminal node, clean up the names first
			my $name = $node->get_name;
			$name =~ s/-.*//;
			print $name, '-';
			
			# climb up the tree
			while( $node = $node->get_parent ) {
			
				# the root MD5 hash
				if ( $node->is_root ) {
					print $node->get_name, '-';
				}
				
				# the internal nodes by index
				print $node->get_generic('l'), 
					'.', 
					$node->get_generic('r'), 
					':', 
					$node->get_branch_length || 0, 
					"\t";
			}			
			print "\n";
		}
	}
);