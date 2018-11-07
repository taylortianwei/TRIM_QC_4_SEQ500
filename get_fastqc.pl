use strict;
use Data::Dumper;
use File::Path;

if(@ARGV < 3){
	print "perl $0 <fastq files record> <outdir> <prefix\n";
	exit;
}
my $fqfile=shift;
my $out=shift;
my $prefix=shift;
my $temp="/share/Data01/tianwei/FASTQC/";
mkpath("$out/$prefix");
mkpath("$temp/$prefix");

(open FQ,$fqfile) || die $!;
open QSUB,">$temp/$prefix/qsub.sh";
open QQ,">$out/$prefix/qsub.sh";
while(<FQ>){
	chomp;
	my @cc=split;
	$cc[0]=~/(CL\d+)\_(L\d+)\_(.*)/ or $cc[0]=~/(V\d+)\_(L\d+)\_(.*)/;
	my ($flowcell,$lane,$smp)=($1,$2,$3);
	(open S,">$temp/$prefix/$flowcell\_$lane\_$smp\_fqc.sh") || die $!;
	my ($fq1,$fq2)=($cc[0]."_1.fq.gz",$cc[0]."_2.fq.gz");
print "$fq1\n$fq2\n";

	if(not -e $fq2){
		$fq2="";
	}
	print S "
#!/bin/bash
#\$ -N fqc_$cc[2]
#\$ -cwd
#\$ -pe mpi 2 
#\$ -l h_vmem=24G
#\$ -l virtual_free=100M
#\$ -l h_rt=72:00:00
#\$ -o $temp/$prefix/$flowcell\_$lane\_$smp\_fqc.o
#\$ -e $temp/$prefix/$flowcell\_$lane\_$smp\_fqc.e

set -e
/share/app/FastQC-0.11.3/fastqc -o $temp/$prefix -a /share/Data01/tianwei/Test/human/test/fastqc/adaptors.txt $fq1 $fq2
cp $temp/$prefix/*.html $temp/$prefix/*.zip $out/$prefix
echo Success!! > $temp/$prefix/$flowcell\_$lane\_$smp\_fqc.sign
";
	close S;
	
	print QSUB "qsub $temp/$prefix/$flowcell\_$lane\_$smp\_fqc.sh\n";
	print QQ "qsub $temp/$prefix/$flowcell\_$lane\_$smp\_fqc.sh\n";

}
close QSUB;
