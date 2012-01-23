package Bio::PhyloTastic::XMLBuilder::MapReduce;
use Moose::Role;
use Bio::Phylo::Util::Logger ':levels';
use Digest::MD5 'md5_hex';

my $logger = Bio::Phylo::Util::Logger->new( '-level' => INFO );

=item map($self,$bipartition)

=cut

sub map {
    my ( $self, $bipartition ) = @_;
    my ( $tips, $node ) = split /\t/, $bipartition;
    for my $tip ( split /\|/, $tips ) {
        $logger->debug($tip . "\t" . $node);
        $self->emit( $tip, $node );        
    }
}

=item combine($self,$tip,$iter)

=cut

sub combine { 
    my ( $self, $tip, $iter ) = @_;
    my @nodes;
    while ( $iter->has_next ) {
        my %node;
        ( $node{node}, $node{count} ) = split /,/, $iter->next;
        push @nodes, \%node;
    }
    my @sorted = sort { $a->{count} <=> $b->{count} } @nodes;
    $self->emit( $tip, $sorted[0]->{node} . ',0' );
    for my $i ( 1 .. $#sorted ) {
        my $flag = $i == $#sorted ? 2 : 1;
        my $child_name  = $sorted[$i-1]->{node};
        my $parent_name = $sorted[$i]->{node};
        $logger->debug( $child_name . "\t" . $parent_name );
        $self->emit( $child_name, $parent_name . ',' . $flag );
    }
}

=item reduce($self,$child,$iter)

=cut

{
    my $done;    
    sub reduce {
        my ( $self, $child, $iter ) = @_;
        my ( $parent, $is_internal ) = split /,/, $iter->next;
        my ( $child_id, $parent_id ) = ( md5_hex($child), md5_hex($parent) );
        if ( $is_internal ) {
            $self->emit("<node id='$child_id' label='$child'/>");
            if ( $is_internal == 2 ) {
                $self->emit("<node id='$parent_id' label='$parent'/>") unless $done++;
            }
        }
        else {
            $self->emit("<otu id='_$child_id' label='$child'/>");
            $self->emit("<node id='$child_id' otu='_$child_id' label='$child'/>");        
        }
        $self->emit("<edge source='$parent_id' target='$child_id'/>");    
    }
}

package Bio::PhyloTastic::XMLBuilder::Mapper;
use Moose;
with 'Hadoop::Streaming::Mapper', 'Bio::PhyloTastic::XMLBuilder::MapReduce';

package Bio::PhyloTastic::XMLBuilder::Combiner;
use Moose;
with 'Hadoop::Streaming::Combiner', 'Bio::PhyloTastic::XMLBuilder::MapReduce';

package Bio::PhyloTastic::XMLBuilder::Reducer;
use Moose;
with 'Hadoop::Streaming::Reducer', 'Bio::PhyloTastic::XMLBuilder::MapReduce';

1;

