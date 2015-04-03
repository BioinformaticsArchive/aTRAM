#!/usr/bin/env perl
package Abyss;
use strict;
use System;
use Parsing;
use Configuration;


###  Set these at each iteration
# -c minimum k-mer coverage
#  -e minimum k-mer errossion
#  -n number of pairs to make a contig

# Assembler modules need to know:
	# where to find the short reads (pass this in as a file name)
	# what the assembly parameters are. (pass this in as a hash)
# Assembler modules should return a hash of the resulting contigs.

my $binaries = {'abyss-pe' => "abyss-pe"};

sub get_binaries {
	return $binaries;
}

sub assembler {
	my $self = shift;
	my $short_read_file = shift;
	my $params = shift;
#        print "spliting short read file into two files. $short_read_file $short_read_file\_1.fasta $short_read_file\_2.fasta\n";
	open FH, "<$short_read_file";
	open RD1, ">$short_read_file\_1.fasta";
	open RD2, ">$short_read_file\_2.fasta";
	my $flag=0;
	my $lib='library';
	while (<FH>) {
	    if ($flag == 1 && ! />/) { 
		my $seq=$_;
		chomp $seq;
		print RD1 "$seq\n"; 
	    }
	    if ($flag == 2 && ! />/) {
		my $seq=$_;
		chomp $seq;
		print RD2 "$seq\n"; 
	    }
	    if (/>(.*?)\/1/) {
		my $name=$1;
		$flag=1;
		print RD1;
	    }
	    if (/>(.*?)\/2/) {
		$flag=2;
		my $name=$2;
		print RD2;
	    }
	}
	Configuration::initialize();
	my ($kmer, $kmer2, $tempdir, $output_file) = 0;
	my $longreads = "";
	if ((ref $params) =~ /HASH/) {
	    if (exists $params->{"kmer"}) {
		$kmer = $params->{"kmer"};
	    }
	    if (exists $params->{"tempdir"}) {
		$tempdir = $params->{"tempdir"};
	    }
	    if (exists $params->{"longreads"}) {
		$longreads = $params->{"longreads"};
	    }
	    if (exists $params->{"output"}) {
		$output_file = $params->{"output"};
	    }
	    if (exists $params->{"log_file"}) {
		set_log($params->{"log_file"});
	    }
	}
	# using ABySS
	# truncate ABySS log file if it already exists
	truncate "$tempdir/Log", 0;
	if ($longreads ne "") {
	    $kmer2= 2*$kmer-10;
	    ### abyss paired end
	    my $string ="v=-v k=$kmer name=$short_read_file\_temp se='$short_read_file\_1.fasta $short_read_file\_2.fasta $longreads'";
#	    print "$string\n\n";
            run_command (get_bin($binaries->{'abyss-pe'}), $string,1);
	} else {
	    my $string="v=-v k=$kmer name=$short_read_file\_temp  se='$short_read_file\_1.fasta $short_read_file\_2.fasta'";
#	    print "$string\n\n";
	    run_command (get_bin($binaries->{'abyss-pe'}), $string,1);
	}
	my $str = "$short_read_file\_temp-unitigs.fa";
	my ($contigs, undef) = parsefasta ($str);
#	print "$str\n\n";
	# copy ABySS log output to logfile.
	open LOGFH, "<:crlf", "$tempdir/Log";
	printlog ("Abyss log:");
	foreach my $line (<LOGFH>) {
	    chomp $line;
	    printlog ($line);
	}
	printlog ("end Abyss log");
	close LOGFH;
	open OUTFH, ">", $output_file;
	foreach my $contigname (keys %$contigs) {
	    my $sequence = $contigs->{$contigname};
	    print OUTFH ">$contigname\n$sequence\n";
	}
	###### remove temp files from abyss
	`rm $short_read_file\_temp*`; 
	close OUTFH;	
	return $contigs;
}
return 1;

