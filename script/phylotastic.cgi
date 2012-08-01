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
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
   "http://www.w3.org/TR/html4/loose.dtd">

<html lang="en">
<head>
	<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
	<title>Tolomatic -- Phylotastic topology service demo</title>
	<!-- we're not going to use this for now 
	    <link rel="stylesheet" type="text/css" href="css/phylotastic.css">
	-->
</head>
    <body>
    <table>
    <tr> <!-- the first row with "about" and logo --> 
		<td width="25%" border="1">
			Welcome! This prototype, which is part of a larger project (<a href="http://www.phylotastic.org">Phylotastic!</a>) to make the "Tree of Life" accessible to researchers, takes a very big tree and a list of taxa, and returns a topology for just those taxa. 
		</td>
		<td align="right"><img src="http://www.evoio.org/wg/evoio/images/f/f1/Phylotastic_logo.png"/></td>
    </tr>
    <tr> <!-- the second row with form on right, top half of instrutions on left -->
		<td align="center"> <!-- how to do the demo --> 
			<b>Try it!</b>
			<br>
			Using the form at right, select a source tree, enter a list of scientific names, and click "Get Phylotastic Tree!"
		</td>
		<td align="left"> <!-- the form --> 
			<form action="phylotastic.cgi" method="get">
			<fieldset>
			   <label for="treeSelector">Source tree:</label>
				<select name="tree" id="treeSelector">
					<option value="mammals">mammals</option>				
					<option value="fishes">fishes</option>
					<option value="tol">tol</option>
					<option value="angiosperms">angiosperms</option>
					<option value="fishes">fishes</option>
					<option value="phylomatic">phylomatic</option>
				</select>
				<label for="formatSelector">Output format:</label>
				<select name="format" id="formatSelector">
					<option value="newick">Newick</option>
					<option value="nexus">Nexus</option>
					<option value="nexml">NeXML</option>
					<option value="nexml">PhyloXML</option>					
				</select>
				<input value="Get Phylotastic Tree!" type="submit"/>
				<br>
				<label for="speciesList">Species list:</label>
				<textarea id="speciesList" name="species" width="600" height="100"></textarea>				
			</fieldset>
			</form>
		</td>
	</tr>
    <tr> <!-- the third row with examples on right, bottom half of instructions on left -->
	<td align="center">Or, you can just copy and paste one of the examples given here
	</td>
	    <td> 
		<table border="1" width="100%"> <!-- the table of examples -->
			<tr>
				<th>Example</th><th>Source tree</th><th>Species list (copy and paste)</th>
			</tr>
			<tr>
				<td>primates</td><td>mammals</td><td>Homo sapiens, Pan troglodytes, Gorilla gorilla</td>
			</tr>
			<tr>
				<td>pets</td><td>mammals</td><td>Felis sylvestris, Canis familiaris, Cavia porcellus, Mustela nigripes</td>
			</tr>
			<tr>
				<td>tbd</td><td>fishes</td><td>[isn't this a family-level tree?]</td>
			</tr>
			<tr>
				<td>tbd</td><td>tol</td><td>tbd</td>
			</tr>
			<tr>
				<td>tbd</td><td>angio</td><td>tbd</td>
			</tr>
			<tr>
				<td>tbd</td><td>phylomatic</td><td>tbd</td>
			</tr>
		</table>    
    </td>
	</tr>
    <tr> <!-- the fourth row with additional info -->
		<td colspan="2" align="left">
		More information
		<ul>
		<li><b>How it works</b>.  Pruning can be done by recursive calls into a database (which probably would need to hit the database many times) or by loading the whole tree into memory (which might take a while to read in the file, and cost a bit of memory).  The way it is done here is much cooler, because it never requires the whole tree to be in memory or in a database: the pruning is done in parallel using <a href="http://en.wikipedia.org/wiki/MapReduce">MapReduce</a>.  Some tests on the entire dump of the <a href="http://tolweb.org">Tree of Life Web Project</a> showed that this returns a pruned subtree within a few seconds, fast enough for a web service.  To find out more, read the <a href="https://github.com/phylotastic/tolomatic/blob/master/README.pod">online docs at github</a>. 
		<li><b>Source trees</b>.  Some information on the source trees used in this project is available in the <a href="http://www.evoio.org/wiki/Phylotastic/Use_Cases#Big_Trees">Big Trees</a> section of the Phylotastic use-cases page.  
		<li><b>The web-services API</b>.  This web page invokes a web service with a simple API exemplified in the following URL:
		<br> <code>phylotastic.cgi?format=newick&tree=mammals&species=Homo_sapiens,Pan_troglodytes,Gorilla_gorilla</code>
		<li><b>Source code</b>. Source code for <a href="https://github.com/phylotastic/tolomatic/">this project</a> (and <a href="https://github.com/phylotastic/">other phylotastic projects</a>) is available at github.  
		</ul>
		</td>
	</tr>
    </table>
    </body>
</html>