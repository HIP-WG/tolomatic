package Bio::PhyloTastic::Pruner::MapReduce;
use Moose::Role;
use Scalar::Util 'refaddr';
use Digest::MD5 'md5_hex';

die "Need DATADIR environment variable" if not -d $ENV{'DATADIR'};

sub map { 
    my ($self, $taxon) = @_;
    my $file = $ENV{'DATADIR'} . '/' . md5_hex($taxon);
    open my $fh, '<', $file or die "Can't process taxon ${taxon} (${file}): $!";
    my @lines = <$fh>;
    my @fields = split /\t/, $lines[0];    
    for my $i ( 1 .. $#fields ) {
        $self->emit( 'child:'.$fields[$i-1], 'parent:'.$fields[$i] );        
    }
}

{
    my %seen_branch;
    my %child_of;
    sub combine { 
        my ( $self, $child, $iter ) = @_;
        ITEM: while( $iter->has_next ) {
            my $parent = $iter->next;
            my $branch = "$child,$parent";
            
            # this so that we don't print out duplicate branches, which
            # occur for branches that are on the path to the root for
            # multiple nodes
            $seen_branch{$branch}++;
            next ITEM if $seen_branch{$branch} > 1;
            
            # this so that we only print parents the second time they are
            # seen, i.e. to prevent unbranched internals and unbranched
            # paths below the root
            if ( not exists $child_of{$parent} ) {
                $child_of{$parent} = $child;
                if ( $child =~ /^child:\d+$/ ) {
                    next ITEM;
                }
            }
            else {
                $self->emit( $child_of{$parent}, $parent ) if defined $child_of{$parent};
                $child_of{$parent} = undef;
            }
            $self->emit( $child, $parent );
        }
    }
}

{
    my %parent_of;
    my %seen_parent;
    sub reduce { 
        my ( $self, $child, $iter ) = @_;
        while ( $iter->has_next ) {
            my $parent = $iter->next;
            
            if ( $child !~ /^child:\d+$/ ) {
                $self->emit( $child, $parent );
            }
            
            # if the branch is an internal branch, i.e. $key =~ /^child:/, only
            # print it out if we've seen the child more than once as a parent            
            $seen_parent{$parent}++;
            $parent_of{$child} = $parent;
            for my $stored_parent ( keys %seen_parent ) {
                if ( $seen_parent{$stored_parent} == 2 ) {
                    my $parent_as_child = $stored_parent;
                    $parent_as_child =~ s/^parent:/child:/;
                    if ( $parent_of{$parent_as_child} ) {
                        $self->emit( $parent_as_child, $parent_of{$parent_as_child} );
                        delete $parent_of{$parent_as_child};
                        delete $seen_parent{$stored_parent};
                    }
                }
            }
        }
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
