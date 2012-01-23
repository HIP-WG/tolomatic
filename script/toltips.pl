#!/usr/bin/perl
use strict;
use Getopt::Long;
use Bio::Phylo::IO 'parse';
use Bio::Phylo::Util::CONSTANT ':objecttypes';

my ( $file, $clade );
GetOptions(
	'file=s'  => \$file,
	'clade=s' => \$clade,
);
my %args = ( 
	'-file'       => $file, 
	'-format'     => 'tolweb',
	'-as_project' => 1,
);

my ($tree) = @{ parse(%args)->get_items(_TREE_) };
my $node = $tree->get_by_name($clade);
if ( $node ) {
	my @tips = @{ $node->get_terminals };
	print $_->get_name, "\n" for @tips;
}
else {
	die "Couldn't find clade $clade\n";
}