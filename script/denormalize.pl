#!/usr/bin/perl
use strict;
use Megatree;
use Getopt::Long;
use Bio::PhyloTastic::Pruner::Util;
use Bio::Phylo::Util::Logger ':levels';

# process command line arguments
my $verbosity = WARN;
my ( $dbfile, $config, $rootid, $treeid );
GetOptions(
	'dbfile=s' => \$dbfile, # e.g. Smith_2011_angiosperms.db
	'config=s' => \$config, # e.g. ../conf/config.ini
	'rootid=i' => \$rootid, # e.g. 571 for Smith_2011_angiosperms.db
	'treeid=s' => \$treeid, # http://example.org/deleteme
	'verbose+' => \$verbosity,
);

# instantiate helper objects
my $log  = Bio::Phylo::Util::Logger->new( '-level' => $verbosity );
my $megatree = Megatree->connect($dbfile);
my $util = Bio::PhyloTastic::Pruner::Util->new($config);
my $root = $megatree->resultset('Node')->find($rootid);
$log->info($root->get_name);

# start the traversal
traverse($root);

sub traverse {
	my $node = shift;
	$log->info("visiting node ".$node->get_name);
	my @children = @{ $node->get_children };
	if ( not @children ) {
		$util->write_taxon_file($treeid,path($node));
	}
	traverse($_) for @children;
}

sub path {
	my $tip = shift;
	my $name = $tip->get_name;
	my $node = $tip->get_parent;
	$log->info("writing path for tip $name");	
	my @path = ( $tip->get_name );
	while( $node ) {
		push @path, $node->get_id;
		$node = $node->get_parent;
	}
	return @path;
}