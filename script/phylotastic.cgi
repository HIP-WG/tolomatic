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
	'tolweb'        => 'http://phylotastic-wg.nescent.org/examples/rawdata/TOL.xml',
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
#
# had to cut this out to allow use of phylomatic tree which is all lowercase names
# tr/A-Z/a-z/ for @species; # lower-case the whole thing
# s/^(\w)/\u$1/ for @species; # capitalize first word

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
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
   "http://www.w3.org/TR/html4/loose.dtd">

<html lang="en">
<head>
	<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
	<title>Phylotastic topology server prototype using MapReduce</title>
	    <link rel="stylesheet" type="text/css" href="http://phylotastic.org/css/phylotastic.css">
</head>
    <body>
    <table>
    <tr> <!-- the first row with "about" and logo --> 
		<td width="25%" align="center">
			Welcome! <br>This prototype pruner takes a very big tree (e.g., 100K nodes) and a list of taxa, and returns a topology for just those taxa. 
		</td>
		<td align="center"><a href="http://www.phylotastic.org"><img src="http://www.evoio.org/wg/evoio/images/f/f1/Phylotastic_logo.png"/></a>
		<br>Automated access to the Tree of Life
		</td>
		<td><!-- intentionally blank, could be used for sponsor logos -->
		</td>
    </tr>
    <tr bgcolor="#61D27F"> <!-- second row with form on right, instructions on left -->
		<td align="center"> <!-- how to do the demo --> 
			<b>Try it!</b>
			<br>
			Using the form at right, enter a list of scientific names, select a source tree, and click "Get Phylotastic Tree!"
		</td>
		<form action="phylotastic.cgi" method="get"> <!-- the form --> 
		<fieldset>
		<td align="left">			
				<br>
				<label for="speciesList">Species list:</label>
				<textarea id="speciesList" name="species" class="species"></textarea>		
			   <label for="treeSelector">Source tree:</label>
				<select name="tree" id="treeSelector">
					<option value="mammals">mammals</option>				
					<option value="fishes">fishes</option>
					<option value="tolweb">tolweb</option>
					<option value="angiosperms">angiosperms</option>
					<option value="phylomatic">phylomatic</option>
				</select>
				<label for="formatSelector">Output format:</label>
				<select name="format" id="formatSelector">
					<option value="newick">Newick</option>
					<option value="nexus">Nexus</option>
					<option value="nexml">NeXML</option>
					<option value="nexml">PhyloXML</option>					
				</select>
		</td>
		<td>
			 <input value="Get Phylotastic Tree!" type="submit"/>
		</td>
		</fieldset>
		</form>
	</tr>
    <tr  bgcolor="#61D27F"> <!-- third row with examples on right, instructions on left -->
	<td align="center">Or, you can just copy and paste one of the examples here
	</td>
	    <td colspan="2"> 
		<table class="examples" border="1"> <!-- the table of examples -->
			<tr>
				<th>Example</th><th>Source tree</th><th>Species list (copy and paste)</th>
			</tr>
			<tr>
				<td>great apes</td><td>mammals</td><td>Homo sapiens, Pan troglodytes, Gorilla gorilla, Pongo pygmaeus</td>
			</tr>
			<tr>
				<td>pets</td><td>mammals</td><td>Felis silvestris, Canis lupus, Cavia porcellus, Mustela nigripes</td>
			</tr>
			<tr>
				<td>musical fish (families)</td><td>fishes</td><td>Aulostomidae, Rhinobatidae, Syngnathidae, Sciaenidae</td>
			</tr>
			<tr>
				<td>tree nuts</td><td>angio</td><td>Macadamia integrifolia, Pinus edulis, Corylus heterophylla, Pistacia vera, Castanea dentata, Juglans nigra, Prunus dulcis, Bertholletia excelsa</td>
			</tr>
			<tr>
				<td>cool ants</td><td>tolweb</td><td>Oecophylla smaragdina,  Camponotus inflatus, Myrmecia pilosula</td>
			</tr>
			<tr>
				<td>tree nuts (genera)</td><td>phylomatic</td><td>macadamia integrifolia, pinus, corylus heterophylla, pistacia, castanea, juglans, prunus, bertholletia</td>
			</tr>
		</table>    
    </td>
	</tr>
    </table>
		<ul class="information">
		<li><b>What's missing?</b>  This prototype uses exact matching with names in source trees (so be sure to get the exact scientific name, and follow the capitalization rules in the examples), but a more robust system would correct typos, fix capitalization, and use a Taxonomic Name Resolution Service (TNRS) that recognizes synonyms (and perhaps, common names).  A more flexible system might allow taxonomic grafting (i.e., adding a species based on its genera or family).  This service returns only a topology, without branch lengths or other information, whereas a more complete phylotastic system would supply branch lengths and provenance information.  
		<li><b>How it works</b>.  Pruning can be done by recursive calls into a database (which probably would need to hit the database many times) or by loading the whole tree into memory (which might take a while to read in the file, and cost a bit of memory).  The way it is done here is much cooler, because it never requires the whole tree to be in memory or in a database: the pruning is done in parallel using <a href="http://en.wikipedia.org/wiki/MapReduce">MapReduce</a>.  Some tests on the entire dump of the <a href="http://tolweb.org">Tree of Life Web Project</a> showed that this returns a pruned subtree within a few seconds, fast enough for a web service.  To find out more, read the <a href="https://github.com/phylotastic/tolomatic/blob/master/README.pod">online docs at github</a>. 
		<li><b>Source trees</b>.  Some information on the source trees used in this project is as follows: 
		<ul>
		<li><b>mammals</b>: 4500 mammal species from Bininda-Emonds, et al. 2007. 
		<li><b>fishes</b>: fish families from Westneat & Lundberg
		<li><b>tolweb</b>: XML dump of entire phylogeny from tolweb.org
		<li><b>angio</b>: Smith, et al., 2011 phylogeny of angiosperms
		<li><b>phylomatic</b>: tree of plant taxa from the Phylomatic program (Webb & Donoghue, 2005)
		</ul>
The mammals tree includes the vast majority of known extant mammals, but the other trees are missing many known species.  Some of these trees do not include species, but only higher taxonomic units (genera, families, orders). 
		<li><b>The web-services API</b>.  This web page invokes a web service with a simple API exemplified in the following URL:
		<br> <code>phylotastic.cgi?format=newick&tree=mammals&species=Homo_sapiens,Pan_troglodytes,Gorilla_gorilla</code>
		<li><b>Source code</b>. Source code for <a href="https://github.com/phylotastic/tolomatic/">this project</a> (and <a href="https://github.com/phylotastic/">other phylotastic projects</a>) is available at github.  
		<li><b>Musical fish?</b>  That's a joke referring to the families of Guitarfish, Trumpetfish, Pipefish, and Drum.  The tree nuts are chestnut (Castanea), almond (Prunus), hazelnut (Corylus), walnut (Juglans), Brazilnut (Bertholletia), macadamia, pine nut, and pistachio.  The pets are cat, dog, guinea pig, and ferret.  
    </body>
</html>