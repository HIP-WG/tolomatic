#!/usr/bin/perl
use strict;
use Bio::Phylo::IO 'parse';
use Bio::Phylo::Util::CONSTANT ':objecttypes';
use Getopt::Long;
use Digest::MD5 'md5_hex';

my ( $file, $format, $dir, $url );
GetOptions(
	'file=s'   => \$file,
	'url=s'    => \$url,
	'format=s' => \$format,
	'dir=s'    => \$dir,
);

mkdir $dir if not -d $dir;
my %args = ( 
	'-format'     => $format,
	'-as_project' => 1,
);
$file ? $args{'-file'} = $file : $url ? $args{'-url'} = $url : die "Need -file or -url";
my ($tree) = @{ parse(%args)->get_items(_TREE_) };

my $counter = 1;
$tree->visit_depth_first(
	'-post' => sub {
		my $node = shift;
		$node->set_name($counter++) if $node->is_internal;
	}
);

$tree->visit_depth_first(
	'-pre' => sub {
		my $node = shift;
		if ( my $parent = $node->get_parent ) {
			my @path = @{ $parent->get_generic('path') };
			unshift @path, $node->get_internal_name;
			$node->set_generic( 'path' => \@path );
			if ( $node->is_terminal ) {
				my $filename = md5_hex($path[0]);
				open my $fh, '>', "${dir}/${filename}" or die "Can't open ${dir}/${filename}: $!";
				print $fh join "\t", @path;
				close $fh;
				print $filename, "\t", $path[0], "\n";
			}
		}
		else {
			$node->set_generic( 'path' => [ $node->get_internal_name ] );
		}
	}
);