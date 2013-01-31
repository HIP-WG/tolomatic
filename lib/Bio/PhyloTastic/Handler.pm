package Bio::PhyloTastic::Handler;
use strict;
use CGI;
use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::Const -compile => qw(OK SERVER_ERROR);
use URI::Escape;
use Data::Dumper;
use Bio::Phylo::IO 'unparse';
use Bio::PhyloTastic::Pruner::Util;
use Bio::PhyloTastic::Pruner::Runner::Mock;
use Bio::PhyloTastic::Pruner::CONSTANT qw(TREEID TAXALIST);

# fetch the constants
my $treeid   = TREEID;
my $taxalist = TAXALIST;

# instantiate helper object
my $util = Bio::PhyloTastic::Pruner::Util->new;

sub handler {
	my $r = shift;
	
	# we need the CGI object to obtain the url-encoded CQL query
	my $cgi    = CGI->new;
	my $query  = $cgi->param('query');
	my $format = $cgi->param('format') || 'nexml';
	my %result = $util->parse_cql($query);
	
	# this invokes the MapReduce process, using a mock for now
	my $project = Bio::PhyloTastic::Pruner::Runner::Mock->run(%result);
	
	# print the content type header depending on requested output
	if ( $format =~ /xml$/ ) {
		$r->content_type('application/xml');
	}
	else {
		$r->content_type('text/plain');
	}
	
	# print the output
	print unparse( '-phylo' => $project, '-format' => $format );
	
	return Apache2::Const::OK;
}
1;
