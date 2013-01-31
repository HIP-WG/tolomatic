package Bio::PhyloTastic::Pruner::Util;
use strict;
use warnings;
use JSON;
use CQL::Parser;
use URI::Escape;
use Config::Tiny;
use Data::Dumper;
use Bio::Phylo::Factory;
use Digest::MD5 'md5_hex';
use File::Path 'make_path';
use Bio::Phylo::Util::Logger;
use Bio::PhyloTastic::Pruner::CONSTANT qw(TREEID TAXALIST);

# fetch the constants
my $treeid   = TREEID;
my $taxalist = TAXALIST;

use base 'Config::Tiny';

my $log = Bio::Phylo::Util::Logger->new;
my $SINGLETON;

sub new {
	my $class  = shift;
	if ( not $SINGLETON ) {
		my $config = shift || $ENV{PHYLOTASTIC_MAPREDUCE_CONFIG};
		
		# read the config file once
		if ( -e $config ) {
			$log->info("going to read config $config");
			$SINGLETON = $class->read( $config );
			$log->VERBOSE( '-level' => $SINGLETON->{_}->{loglevel} );
			$log->info("data root is ".$SINGLETON->{_}->{dataroot} );
		}
		else {
			die "Couldn't read config file '$config'";
		}
	}
	return $SINGLETON;
}

sub tree { $ENV{PHYLOTASTIC_MAPREDUCE_TREE} }

sub logger { $log }

sub encode_taxon {
	my ($self,$taxon) = @_;
	
	# the encoding is a simple MD5 checksum
	my $hash = md5_hex($taxon);
	
	return $hash;
}

sub taxon_dir {
	my ($self,$tree,$taxon) = @_;
	
	# need to know the context of the tree
	if ( not $tree ) {
		$tree = $self->tree or die "No tree PURL provided!";
	}
	
	# input tree URI should map onto a data dir
	my $dir  = $self->{_}->{dataroot} . '/' . $self->{$tree}->{datadir};
	
	# encode the taxon name
	my $encoded = $self->encode_taxon($taxon);
	
	# compute the final path
	my @parts = split //, $encoded;
	my $taxon_dir = join '/', @parts[ 0 .. $self->{_}->{hashdepth} ];
	my $path = $dir . '/' . $taxon_dir . '/';
	
	return wantarray ? ($path, $encoded) : $path;
}

sub read_taxon_file {
	my ($self,$file) = @_;
	
	# open file handle or warn and return
	open my $fh, '<', $file or $log->warn("no path '$file': $!") and return;
	
	# slurp file
    my @lines = <$fh>;
	chomp(@lines);
    my @fields = split /\t/, $lines[0];
	$log->debug("root-to-tip path is @fields");
	
	return @fields;
}

sub write_taxon_file {
	my ($self,$tree,@path) = @_;
	
	# first part of path should be UN-encoded taxon name
	my $taxon = $path[0];
	$taxon =~ s/:.+//; # strip branch length
	my ($dir,$file) = $self->taxon_dir($tree,$taxon);
	
	# make the path if it didn't already exist
	if ( not -d $dir ) {
		make_path($dir);
	}
	
	# write the path
	open my $fh, '>', "$dir/$file" or die $!;
	print $fh join "\t", @path;
	close $fh;
	
	return "$dir/$file";
}

sub read_outfile {
	my ($self,$file) = @_;
	
	# build ancestor paths for all tips
	my %ancestors;
	{
		open my $fh, '<', $file or die $!;
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
	
	return $tree;
}

sub parse_cql {
	my ($self,$query) = @_;
	my %result; # hash with 'tree' and 'taxa'
	
	# instantiate the CQL parser, parse string to syntax tree
	my $parser = CQL::Parser->new;
	my $root = $parser->parse($query);
	
	# the root node has to be an "AND" node for the two terms
	if ( UNIVERSAL::isa($root,'CQL::AndNode') ) {
		
		# iterate over the children
		for my $child ( $root->left, $root->right ) {
			
			# all children need to be term nodes
			if ( UNIVERSAL::isa($child,'CQL::TermNode') ) {
				
				# it's either the taxa list or the tree id
				if ( $child->getQualifier eq $taxalist ) {
					$result{$taxalist} = decode_json(uri_unescape($child->getTerm));
				}
				elsif ( $child->getQualifier eq $treeid ) {
					$result{$treeid} = uri_unescape($child->getTerm);
				}
			}
			else {
				$log->warn("child CQL node not a TERM node");
			}
		}
	}
	else {
		$log->warn("root of CQL syntax tree not an AND node");
	}
	return %result;
}


1;