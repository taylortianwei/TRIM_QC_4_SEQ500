use strict;
use Data::Dumper;
use File::Path;

if(@ARGV < 3){
	print "perl $0 <fastq files record> <outdir> <prefix\n";
	exit;
}
my $fqfile=shift;
my $pjid=shift;
my $out=shift;
my $prefix=shift;
my $c=shift;

my $temp="/share/Data01/tianwei/FASTQC/";
my $ftp="/ftp";
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
	(open S,">$temp/$prefix/$flowcell\_$lane\_$smp\_qc.sh") || die $!;
	my ($fq1,$fq2)=($cc[0]."_1.fq.gz",$cc[0]."_2.fq.gz");
print "$fq1\n$fq2\n";

	if(not -e $fq2){
		$fq2="";
	}
	print S "
#!/bin/bash
#\$ -N qc_$cc[2]
#\$ -cwd
#\$ -pe mpi 2 
#\$ -l h_vmem=24G
#\$ -l virtual_free=100M
#\$ -l h_rt=72:00:00
#\$ -o $temp/$prefix/$flowcell\_$lane\_$smp\_qc.o
#\$ -e $temp/$prefix/$flowcell\_$lane\_$smp\_qc.e

set -e
mkdir -p $temp/$prefix/$flowcell\_$lane\_$smp
/share/Data01/tianwei/Bin/DNA_CSAP_v5.2.7/bin/SOAPnuke filter -1 $fq1 -2 $fq2 -t 0,0,0,$c -Q 2 -o $temp/$prefix/$flowcell\_$lane\_$smp
cp $temp/$prefix/$flowcell\_$lane\_$smp/*.txt $out/$prefix/
#mkdir -p $ftp/$pjid/Raw_Fastq/$cc[-1]
#cp $fq1 $ftp/$pjid/Raw_Fastq/$cc[-1]
#md5sum $fq1 > $ftp/$pjid/Raw_Fastq/$cc[-1]/$fq1.md5
#cp $fq2 $ftp/$pjid/Raw_Fastq/$cc[-1]
#md5sum $fq2 > $ftp/$pjid/Raw_Fastq/$cc[-1]/$fq2.md5

echo Success!! > $temp/$prefix/$flowcell\_$lane\_$smp\_QC.sign
";
	close S;
	
	print QSUB "qsub $temp/$prefix/$flowcell\_$lane\_$smp\_qc.sh\n";
	print QQ "qsub $temp/$prefix/$flowcell\_$lane\_$smp\_qc.sh\n";

}
close QSUB;
