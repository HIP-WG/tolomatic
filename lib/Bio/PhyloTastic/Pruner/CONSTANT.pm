package Bio::PhyloTastic::Pruner::CONSTANT;
require Exporter;
@ISA=qw(Exporter);
@EXPORT_OK=qw(TREEID TAXALIST TAXONID);
sub TREEID   { 'pt.identifier.tree' }
sub TAXALIST { 'pt.taxaForSubtree'  }
sub TAXONID  { 'treestoreId' }
1;