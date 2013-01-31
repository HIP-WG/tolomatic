package Bio::PhyloTastic::Pruner::Runner;
use strict;
use warnings;
use File::Path qw(remove_tree);
use Bio::PhyloTastic::Pruner::Util;
use File::Temp qw(tempfile tempdir);
use Bio::PhyloTastic::Pruner::CONSTANT qw(TREEID TAXALIST TAXONID);

# fetch the constants
my $treeid   = TREEID;
my $taxalist = TAXALIST;
my $taxonid  = TAXONID;

# instantiate helper objects
my $util = Bio::PhyloTastic::Pruner::Util->new;
my $log  = Bio::Phylo::Util::Logger->new( '-level' => $util->{_}->{loglevel} );

sub run {
	my $self = shift;
	my %args = @_;
	
	# the input file is a list of identifiers, one per line
	my ( $fh, $infile ) = tempfile();
	print $fh join "\n", map { $_->{$taxonid} } @{ $args{$taxalist} };
	close $fh;	
	
	# hadoop wants the output dir to be empty - nay, not even there!
	my $tmpdir = $util->{_}->{tmpdir};
	$log->info("infile is $infile");
	$log->info("tmpdir is $tmpdir");
	
	# compose command
	my @command = (
		"$ENV{HADOOP_HOME}/bin/hadoop",
		'jar'       => "$ENV{HADOOP_HOME}/hadoop-$ENV{HADOOP_VERSION}-streaming.jar",
		'-cmdenv'   => 'PHYLOTASTIC_MAPREDUCE_TREE='   . $args{$treeid},
		'-cmdenv'   => 'PHYLOTASTIC_MAPREDUCE_CONFIG=' . $ENV{PHYLOTASTIC_MAPREDUCE_CONFIG},
		'-cmdenv'   => 'PERL5LIB=' . join( ':', @INC ),
		'-input'    => $infile,
		'-output'   => $tmpdir,
		'-mapper'   => $util->{_}->{mapper},
		'-combiner' => $util->{_}->{combiner},
		'-reducer'  => $util->{_}->{reducer},
	);
	$log->info(join ' ',@command);

	# invoke hadoop
	system( @command ) == 0 or die $?;
	
	# return value is the path to the outfile
	return "$tmpdir/part-00000";
}

1;