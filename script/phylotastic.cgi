#!/usr/bin/perl
BEGIN {
	$ENV{PHYLOTASTIC_MAPREDUCE_CONFIG} = '/Users/rvosa/Dropbox/documents/projects/current/tolomatic/conf/config.ini';	
}
use strict;
use warnings;
use CGI;
use URI::Escape;
use Bio::PhyloTastic::Pruner::Util;
use Bio::PhyloTastic::Pruner::Runner;
use Bio::PhyloTastic::Pruner::CONSTANT qw(TREEID TAXALIST);

# fetch the constants
my $treeid   = TREEID;
my $taxalist = TAXALIST;

# instantiate helper object
my $util = Bio::PhyloTastic::Pruner::Util->new;

# we need the CGI object to obtain the url-encoded CQL query
my $cgi    = CGI->new;
my $query  = uri_unescape($cgi->param('query'));
my %result = $util->parse_cql($query);

# this invokes the MapReduce process
my $outfile = Bio::PhyloTastic::Pruner::Runner->run(
	'-tree' => $result{$treeid},
	'-taxa' => [ map { $_->{uri} } @{ $result{$taxalist} } ]
);

# print result
print "Content-type: text/plain\n\n", $util->read_outfile($outfile)->to_newick;
