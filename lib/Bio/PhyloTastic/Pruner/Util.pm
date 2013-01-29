package Bio::PhyloTastic::Pruner::Util;
use strict;
use warnings;
use Config::Tiny;
use Data::Dumper;
use Digest::MD5 'md5_hex';
use File::Path 'make_path';
use Bio::Phylo::Util::Logger;

use base 'Config::Tiny';

my $log = Bio::Phylo::Util::Logger->new;

sub new {
	my $class = shift;
	my $config = shift || $ENV{PHYLOTASTIC_MAPREDUCE_CONFIG};
	if ( -e $config ) {
		$log->info("going to read config $config");
		my $self = $class->read( $config );
		$log->VERBOSE( '-level' => $self->{_}->{loglevel} );
		$log->info("data root is ".$self->{_}->{dataroot} );
		return $self;
	}
	else {
		die "Couldn't read config file '$config'";
	}
}

sub tree { $ENV{PHYLOTASTIC_MAPREDUCE_TREE} }

sub logger { $log }

sub encode_taxon {
	my ($self,$taxon) = @_;
	
	# the encoding is a simple MD5 checksum
	my $hash = md5_hex($taxon);
	$log->debug("$taxon => $hash");
	
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
	$log->debug("datadir for $tree is $dir");
	
	# encode the taxon name
	my $encoded = $self->encode_taxon($taxon);
	
	# compute the final path
	my @parts = split //, $encoded;
	my $taxon_dir = join '/', @parts[ 0 .. $self->{_}->{hashdepth} ];
	my $path = $dir . '/' . $taxon_dir . '/';
	$log->debug("taxon dir location is $path");
	
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
	
	# first parth of path should be UN-encoded taxon name
	my $taxon = $path[0];
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


1;