#!/usr/bin/perl
use strict;
use Bio::Phylo::IO 'parse';
use Bio::Phylo::Util::CONSTANT ':objecttypes';
use Digest::MD5 'md5_hex';

my ($tree) = @{ parse(
	'-format'     => 'tolweb',
	'-url'        => 'http://tolweb.org/data/tolskeletaldump.xml',
	'-as_project' => 1,
)->get_items(_TREE_) };

$tree->visit_depth_first(
	'-pre' => sub {
		my $node = shift;
		if ( my $parent = $node->get_parent ) {
			my @path = @{ $parent->get_generic('path') };
			unshift @path, $node->get_internal_name;
			$node->set_generic( 'path' => \@path );
			if ( $node->is_terminal ) {
				my $filename = md5_hex(@path);
				open my $fh, '>', "tol/${filename}" or die "Can't open ${filename}: $!";
				print $fh join "\t", @path;
				close $fh;
			}
		}
		else {
			$node->set_generic( 'path' => [ $node->get_internal_name ] );
		}
	}
);