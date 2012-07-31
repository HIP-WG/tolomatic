#!/usr/bin/perl -w

use strict; 

my %testinput = ( 
	expected => 'Homo_sapiens,Gorilla_gorilla', 
	spaces_before => ' Homo_sapiens,Gorilla_gorilla',
	spaces_after => 'Homo_sapiens,Gorilla_gorilla  ',
	spaces_in => 'Homo sapiens,Gorilla_gorilla', 
	spaces_between => 'Homo sapiens, Gorilla_gorilla',
	lowercase => 'homo_sapiens,Gorilla_gorilla', 
	various_challenges => ' HoMo sapiens , gorilla_gORILla '
); 
 

foreach my $test (keys(%testinput)) { 
	print "$test: \"$testinput{ $test }\"\n\t"; 
	my $string = $testinput{ $test }; 
	my @species = split( /,/, $string ); 

	s/^\s+|\s+$//g for @species; # remove leading and trailing spaces 
	s/ /_/g for @species;  # convert spaces to underscores
	tr/A-Z/a-z/ for @species; # lower-case the whole thing
	s/^(\w)/\u$1/ for @species; # capitalize first word

	print "\"".join( "\"+\"", @species )."\"\n\n";
}
	
exit; 

# my ( $fh, $filename ) = tempfile();
# print $fh join "\n", @species;
# close $fh;
# 
# 
