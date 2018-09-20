use strict;
use Data::Dumper;
use File::Path;

if(@ARGV < 2){
	print "perl $0 <fastq files record> <outdir>\n";
}
my $fqfile=shift;
my $out=shift;

(open FQ,$fqfile) || die $!;
open QSUB,">$out/qsub.sh";
while(<FQ>){
	chomp;
	/(CL\d+)\_(L\d+)\_(.*)/;
	my ($flowcell,$lane,$smp)=($1,$2,$3);
        mkpath("$out/$flowcell/$lane/$smp");
	(open S,">$out/$flowcell/$lane/$smp/fqc_$smp.sh") || die $!;
	my ($fq1,$fq2)=($_."_1.fq.gz",$_."_2.fq.gz");
	if(not -e $fq2){
		$fq2="";
	}
	print S "
!/bin/bash
#\$ -N fqc_$smp
#\$ -cwd
#\$ -pe mpi 2 
#\$ -l h_vmem=24G
#\$ -l virtual_free=100M
#\$ -l h_rt=72:00:00
#\$ -o $out/$flowcell/$lane/$smp/fqc_$smp.o
#\$ -e $out/$flowcell/$lane/$smp/fqc_$smp.e

set -e
/share/app/FastQC-0.11.3/fastqc -o $out/$flowcell/$lane/$smp -a /share/Data01/tianwei/Test/human/test/fastqc/adaptors.txt $fq1 $fq2
echo Success!! > $out/$flowcell/$lane/$smp/fqc_$smp.sign
";
	close S;
	
	print QSUB "qsub $out/$flowcell/$lane/$smp/fqc_$smp.sh\n";
}
close QSUB;
