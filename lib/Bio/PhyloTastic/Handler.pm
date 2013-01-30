package Bio::PhyloTastic::Handler;
use strict;
use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::Const -compile => qw(OK SERVER_ERROR);

sub handler {
	my $r = shift;
	my $path = $r->path_info;
	my $args = $r->args;
	$r->content_type('text/plain');
	print "path: $path\n";
	print "args: $args\n";
	return Apache2::Const::OK;
}
1;
