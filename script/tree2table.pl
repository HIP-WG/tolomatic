#!/usr/bin/perl
use strict;
use Bio::Phylo::IO 'parse';
use Bio::Phylo::Util::CONSTANT ':objecttypes';
use Getopt::Long;
use Digest::MD5 'md5_hex';

# process command line arguments
my ( $file, $format, $dir, $url, $outfile );
GetOptions(
	'file=s'    => \$file,
	'url=s'     => \$url,
	'format=s'  => \$format,
	'dir=s'     => \$dir,
	'outfile=s' => \$outfile, # if provided, prints to a single file
);

# initialize output dir
mkdir $dir if not -d $dir;

# prepare parser args
my %args = ( 
	'-format'     => $format,
	'-as_project' => 1,
	'-skip'       => [ _MATRIX_ ],
);
$file ? $args{'-file'} = $file : $url ? $args{'-url'} = $url : die "Need -file or -url";

# parse tree
my ($tree) = @{ parse(%args)->get_items(_TREE_) };

# apply node labels
my $counter = 1;
$tree->visit_depth_first(
	'-post' => sub {
		my $node = shift;
		$node->set_name($counter++) if $node->is_internal;
	}
);

# open handle to single $outfile, if provided
my $outfh;
if ( $outfile ) {
	open $outfh, '>', $outfile or die "Can't open $outfile: $!";
}

# write output
$tree->visit_depth_first(
	'-pre' => sub {
		my $node = shift;
		if ( my $parent = $node->get_parent ) {
			
			# extend path
			my @path = @{ $parent->get_generic('path') };
			unshift @path, $node->get_internal_name;
			$node->set_generic( 'path' => \@path );
			
			# print path
			if ( $node->is_terminal ) {
				
				# print to a single file
				if ( $outfh ) {
					my $tip = shift @path;
					my $path = join '|', @path;
					print $outfh "${tip},${path}\n";
				}
				else {
					my $filename = md5_hex($path[0]);
					open my $fh, '>', "${dir}/${filename}" or die "Can't open ${dir}/${filename}: $!";
					print $fh join "\t", @path;
					close $fh;
					
					# print mapping
					print $filename, "\t", $path[0], "\n";
				}
			}
		}
		else {
		
			# start path
			$node->set_generic( 'path' => [ $node->get_internal_name ] );
		}
	}
);