#!/usr/bin/perl

=head1 NAME

PhyloTastic - pruner of megatrees

=head1 SYNOPSIS

 ./phylotastic.cgi --species='Homo_sapiens,Pan_troglodytes,Gorilla_gorilla' --tree=mammals --format=newick

Or, as a CGI script:

 http://example.org/cgi-bin/phylotastic.cgi?species=Homo_sapiens,Pan_troglodytes,Gorilla_gorilla&tree=mammals&format=newick

=head1 DESCRIPTION

This script prunes very large phylogenies down to the topology for a set of user-
defined species.

=head1 OPTIONS

=over

=item species

Species names are provided as a comma-separate list. The names need to match exactly the 
names in the megatrees. Watch out with shell names and URL-encoding!

=item tree

The following trees are available: C<fishes> - the first tree from 
Westneat_Lundberg_BigFishTree.nex, C<mammals> - the first tree from 
Bininda-emonds_2007_mammals.nex, C<tol> - the tree from TOL.xml, C<angio> - the tree from 
Smith_2011_angiosperms.txt, C<phylomatic> - the tree from Phylomatictree.nex

=item format

The following return formats are available: C<NeXML>, C<Newick>, C<Nexus>.

=item help

Prints this help message and quits.

=item verbose

Sets verbosity level, between 0 and 4.

=back

=cut

use lib '../lib';
use strict;
use warnings;
use Pod::HTML;
use Pod::Usage;
use Getopt::Long;
use Bio::Phylo::Factory;
use Bio::Phylo::IO 'unparse';
use Bio::Phylo::Util::Logger ':levels';
use File::Temp qw(tempfile tempdir);
use File::Path qw(remove_tree);
use CGI;
use Cwd;

# so this is obviously dumb, to hardcode it here. sorry. need a config system
my %source = (
	'mammals'    => 'http://phylotastic-wg.nescent.org/examples/rawdata/Bininda-emonds_2007_mammals.nex',
	'fishes'     => 'http://phylotastic-wg.nescent.org/examples/rawdata/Westneat_Lundberg_BigFishTree.nex',
	'tol'        => 'http://phylotastic-wg.nescent.org/examples/rawdata/TOL.xml',
	'angio'      => 'http://phylotastic-wg.nescent.org/examples/rawdata/Smith_2011_angiosperms.txt',
	'phylomatic' => 'http://phylotastic-wg.nescent.org/examples/rawdata/Phylomatictree.nex',
);

# current working directory
my $CWD = getcwd;

# process program arguments
my $cgi = CGI->new;
my %params = $cgi->Vars(",");
GetOptions(
	'help|?'    => \$params{'help'},
	'tree=s'    => \$params{'tree'},
	'species=s' => \$params{'species'},
	'format=s'  => \$params{'format'},
	'verbose+'  => \$params{'verbose'},
);

# print help message and quit
if ( $params{'help'} ) {
	if ( $cgi->param('help') ) {
		print $cgi->header;
		pod2html("pod2html","--infile=$0");
	}
	else {
		pod2usage();
	}
	exit 0;
}

# print web form and quit
if ( exists $ENV{'QUERY_STRING'} and not $ENV{'QUERY_STRING'} ) {
	print $cgi->header;
	print do { local $/; <DATA> };
	exit 0;
}

# make species list 
my @species = split /,/, $params{'species'};

# sanitize list by fixing spaces, underscores, and capitalization
s/^\s+|\s+$//g for @species; # remove leading and trailing spaces 
s/ /_/g for @species;  # convert internal spaces to underscores
tr/A-Z/a-z/ for @species; # lower-case the whole thing
s/^(\w)/\u$1/ for @species; # capitalize first word

my ( $fh, $filename ) = tempfile();
print $fh join "\n", @species;
close $fh;

# extend PERL5LIB
my $PERL5LIB = join ':', @INC;

# create temp dir
remove_tree( $CWD . '/tmp/' );
my $TEMPDIR = $CWD . '/tmp/';

# create path to DATADIR
my $DATADIR = $CWD . '/../examples/' . lc($params{'tree'});

# invoke hadoop
system(
	"$ENV{HADOOP_HOME}/bin/hadoop",
	'jar'       => "$ENV{HADOOP_HOME}/hadoop-$ENV{HADOOP_VERSION}-streaming.jar",
	'-cmdenv'   => 'DATADIR=' . $DATADIR,
	'-cmdenv'   => 'PERL5LIB=' . $PERL5LIB,
	'-input'    => $filename,
	'-output'   => $TEMPDIR,
	'-mapper'   => $CWD . '/pruner/mapper.pl',
	'-combiner' => $CWD . '/pruner/combiner.pl',
	'-reducer'  => $CWD . '/pruner/reducer.pl',
) == 0 or die $?;

# create provenance info
my %provenance = (
	'species' => $params{'species'},
	'treeid'  => $params{'tree'},
	'tnrs'    => 'exactMatch',
	'pruner'  => 'MapReduce',
	'source'  => $source{lc $params{'tree'}},
);
my $defines = join ' ', map { "--define $_='$provenance{$_}'" } keys %provenance;

# print header
my $mime_type = ( $params{format} =~ /xml$/i ) ? 'application/xml' : 'text/plain';
print $cgi->header( $mime_type ) if $ENV{'QUERY_STRING'};

# print content
my $outfile = "$TEMPDIR/part-00000";
print `$CWD/newickify.pl -i $outfile -f $params{'format'} $defines`, "\n";


__DATA__
<html>
    <head>
        <title>phylotastic web</title>
    </head>
    <body>
        <form action="phylotastic.cgi" method="get">
            <fieldset>
				<center><img src="http://www.evoio.org/wg/evoio/images/f/f1/Phylotastic_logo.png"/></center>
                <label for="speciesList">Enter species list (comma-separated):</label>
                <textarea id="speciesList" name="species" width="600" height="100"></textarea>
                <label for="treeSelector">Choose source tree:</label>
                <select name="tree" id="treeSelector">
                    <option value="mammals">mammals</option>				
                    <option value="fishes">fishes</option>
                    <option value="tol">tol</option>
                    <option value="angiosperms">angiosperms</option>
                    <option value="fishes">fishes</option>
                    <option value="phylomatic">phylomatic</option>
                </select>
                <label for="formatSelector">Choose format:</label>
                <select name="format" id="formatSelector">
                    <option value="newick">Newick</option>
                    <option value="nexus">Nexus</option>
                    <option value="nexml">NeXML</option>
                    <option value="nexml">PhyloXML</option>					
                </select>				
                <input value="Get Phylotastic Tree!" type="submit"/>
            </fieldset>
        </form>
		<a href="phylotastic.cgi?format=newick&tree=mammals&species=Homo_sapiens,Pan_troglodytes,Gorilla_gorilla">
		Example query</a> (format=newick, tree=mammals, species="Homo sapiens, Pan troglodytes, Gorilla gorilla")
		)
    </body>
</html>