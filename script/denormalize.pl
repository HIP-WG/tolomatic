#!/usr/bin/perl
use strict;
use Megatree;
use Getopt::Long;
use Bio::PhyloTastic::Pruner::Util;
use Bio::Phylo::Util::Logger ':levels';

# process command line arguments
my $verbosity = WARN;
my ( $dbfile, $config, $rootid, $treeid, $outfile );
GetOptions(
	'dbfile=s'  => \$dbfile, # e.g. Smith_2011_angiosperms.db
	'config=s'  => \$config, # e.g. ../conf/config.ini
	'rootid=i'  => \$rootid, # e.g. 571 for Smith_2011_angiosperms.db
	'treeid=s'  => \$treeid, # http://example.org/deleteme
	'verbose+'  => \$verbosity,
	'outfile=s' => \$outfile,
);

# instantiate helper objects
my $log  = Bio::Phylo::Util::Logger->new( '-level' => $verbosity );
my $megatree = Megatree->connect($dbfile);
my $util = Bio::PhyloTastic::Pruner::Util->new($config);
my $root = $megatree->resultset('Node')->find($rootid);
my $tipcounter = 1;
my %path;
my $outfh;
if ( $outfile ) { open $outfh, '>', $outfile or die $! }
$log->info($root->get_name);

# start the traversal
traverse($root);

sub traverse {
	my $node = shift;
	my @children = @{ $node->get_children };
	if ( not @children ) {
		if ( $outfh ) {
			my @path = path($node);
			print $outfh join("\t",@path), "\n";
		}
		else {
			$util->write_taxon_file($treeid,path($node));
		}
	}
	my $id = $node->id;
	my @path = @{ $path{$id} } if $path{$id};
	unshift @path, $id;
	for my $child ( @children ) {
		$path{$child->id} = \@path;
		traverse($child);
	}
	delete $path{$id};
}

sub path {
	my $tip = shift;
	my $name = $tip->get_name;
	my $node = $tip->get_parent;
	$tipcounter++;
	if ( not $tipcounter % 100 ) {
		$log->info("writing path for tip $tipcounter ($name)");
	}
	my @path = ( $tip->get_name, @{ $path{$tip->id} } );	
	return @path;
}