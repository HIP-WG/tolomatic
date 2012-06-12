package Bio::PhyloTastic::Pruner::MapReduce;
use Moose::Role;
use Scalar::Util 'refaddr';
use Bio::Phylo::Util::Logger ':levels';
use Digest::MD5 'md5_hex';
use Data::Dumper;

die "Need DATADIR environment variable" if not -d $ENV{'DATADIR'};

my $logger = Bio::Phylo::Util::Logger->new( '-level' => INFO );

=item map($self,$taxon)

Given a single taxon name as argument, this method reads in a file inside
$ENV{DATADIR} whose name is the MD5 hex code hash of the taxon name. That
file should contain one line: a tab-separate list that describes the path,
in post-order indexed integers, from taxon to the root. Each segment of
that path is emitted as node ID => taxon. For example, for tree
(((A,B)1,C)2,D)3; if taxon is A, this emits:

 1,A
 2,A
 3,A

=cut

sub map { 
    my ( $self, $taxon ) = @_;
    my $file = $ENV{'DATADIR'} . '/' . md5_hex($taxon);
    $logger->info("taxon: $taxon (file: $file)");
    open my $fh, '<', $file or $logger->warn("Can't process taxon ${taxon} (${file}): $!") and return;
    my @lines = <$fh>;
    my @fields = split /\t/, $lines[0];
    $logger->debug("path: @fields");
    for my $i ( 1 .. $#fields ) {
        $self->emit( $fields[$i], $fields[0] );        
    }
}

=item combine($self,$node,$iter)

Given a node ID (as described for C<map>) as a key, and all the tips that have
that node on their respective paths to the root, this method combines these to
emit a concatenated list of all tips, then the node ID, then the tip count. E.g.
if the node ID is 1, this will be passed:
 
 1,A,B
 
and will emit:

 A|B,1,2

=cut

sub combine { 
    my ( $self, $node, $iter ) = @_;    
    my @tips;
    while( $iter->has_next ) {
        push @tips, $iter->next;        
    }
    $logger->debug("node: $node tips: @tips");
    if ( @tips ) {
        $self->emit( join("|", sort{$a cmp $b} @tips), $node . ',' . scalar(@tips) );
    }
}

=item reduce($self,$tips,$iter)

Given a concatenated list of tips, a node ID and the number of tips it subtends,
this will filter out all nodes that subtend 1 tip. In cases where a concatenated
list of tips has multiple values associated with it, this means that there are
unbranched internal nodes on the path from those tips to the root. Of those
unbranched internals we want the MRCA of the tips, which we obtain by sorting
the node IDs: since these are applied in post-order, the lowest node ID in the
list is the MRCA.

=cut

sub reduce { 
    my ( $self, $tips, $iter ) = @_;
    my @nodes;
    while ( $iter->has_next ) {
        my %tuple;
        ( $tuple{node}, $tuple{count} ) = split /,/, $iter->next;
        push @nodes, \%tuple;
    }
    my @sorted = sort { $a->{node} <=> $b->{node} } grep { $_->{count} > 1 } @nodes;
    if ( @sorted ) {
        my $mrca = $sorted[0];
        $logger->info("mrca: " . $mrca->{node} . " tips: " . $tips);
        $self->emit( $tips, $mrca->{node} . ',' . $mrca->{count} );
    }
}

package Bio::PhyloTastic::Pruner::Mapper;
use Moose;
with 'Hadoop::Streaming::Mapper', 'Bio::PhyloTastic::Pruner::MapReduce';

package Bio::PhyloTastic::Pruner::Combiner;
use Moose;
with 'Hadoop::Streaming::Combiner', 'Bio::PhyloTastic::Pruner::MapReduce';

package Bio::PhyloTastic::Pruner::Reducer;
use Moose;
with 'Hadoop::Streaming::Reducer', 'Bio::PhyloTastic::Pruner::MapReduce';

1;

