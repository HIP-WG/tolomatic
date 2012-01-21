package Bio::PhyloTastic::Pruner::MapReduce;
use Moose::Role;

sub map { 
    my ($self, $line) = @_;
    die "FIXME";
    my ( $key, $value );
    $self->emit( $key => $value);
}

sub reduce { 
    my ( $self, $key, $value_iterator) = @_;
    die "FIXME";
    while( $value_iterator->has_next() ) { }
    my $composite_value;
    $self->emit( $key, $composite_value );
} 

sub combine { 
    my ( $self, $key, $value_iterator) = @_;
    while( $value_iterator->has_next() ) { die "FIXME" }
    my $composite_value;
    $self->emit( $key, $composite_value );
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
