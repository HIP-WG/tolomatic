#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Digest::MD5 'md5_hex';

# process command line arguments
my ( $infile, $chunksize, $outdir );
GetOptions(
	'infile=s'    => \$infile,
	'chunksize=i' => \$chunksize,
	'outdir=s'    => \$outdir,
);
mkdir $outdir if not -d $outdir;

# read the newick string. This assumes one string per file!
my $string;
{
	open my $fh, '<', $infile or die $!;
	while(<$fh>) {
		chomp;
		$string .= $_;
	}
	close $fh;
	
	# trim any leading or trailing whitespace
	$string =~ s/^\s*(\S+?)\s*$/$1/;
}

# string becomes the backbone, which itself should shrink
# to below chunksize
my $full = length($string);
while ( ( $string =~ tr/,/,/ ) > $chunksize ) {

	# progress counter
	print STDERR int( ( 1 - length($string) / $full ) * 100 ) . "%\n";

	# iterate over string, one char at a time
	CHUNK: for my $i ( 0 .. length($string) ) {
		
		# here we may have a clade that's suitable for pruning out
		if ( ')' eq substr $string, $i, 1 ) {

			# now track back
			my $depth = 0;
			for ( my $j = $i + 1; $j >= 0; $j-- ) {
				
				# track depth of the nesting
				my $token = substr $string, $j, 1;
				$depth++ if $token eq ')';
				$depth-- if $token eq '(';
				
				# we're at the first balanced set of parentheses
				if ( $depth == 0 && $j < $i ) {
					my $clade = substr $string, $j, $i - $j + 1;
					my $clade_size = $clade =~ tr/,/,/;
					
					# big enough?
					if ( ( $clade_size / $chunksize ) > 0.95 ) {
						
						# print to a separate file
						my $md5 = md5_hex($clade);
						{
							open my $fh, '>', $outdir . '/' . $md5 . '.dnd' or die $!;
							print $fh $clade, "$md5;\n";
							close $fh;
						}
						
						# shrink the megatree string
						$string =~ s/\Q$clade\E/$md5-/;						
						last CHUNK;
					}
					else {
						next CHUNK;
					}
				}			
			}
		}
	}
}

# now print the backbone
my $md5 = md5_hex($string);
$string =~ s/\)([^\)+])$/)$md5$1/;
{
	my $name = $infile;
	$name =~ s|.+/||;
	open my $fh, '>', $outdir . '/' . $name . '.dnd' or die $!;
	print $fh $string, "\n";
	close $fh;
}