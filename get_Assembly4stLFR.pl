use strict;
use Data::Dumper;
use POSIX;
use File::Path;
use FindBin;
use JSON::XS qw(encode_json decode_json);
use File::Slurp qw(read_file write_file);

my $Bin=$FindBin::Bin;

my $filerecord="$Bin/FilesHash/Files.hash";
my $json=read_file($filerecord, { binmode => ':raw' });
my %FilePath=%{ decode_json $json };

if(@ARGV < 3){
	print "perl $0 <fastq files record> <outdir> <prefix>\n";
	exit ;
}
my $fqfile=shift;
my $OutDir=shift;
my $CalcuDir=shift;

my $threads=16;
my $maxmem=50;
(open FQ,$fqfile) || die $!;

my %rlID_bcID;
mkpath("$CalcuDir");

open QSUB,">$CalcuDir/qsub_assembly.sh";
while(<FQ>){
	chomp;
	my @cc=split(/\t/);
	
	push @{$rlID_bcID{$cc[4]."/".$cc[2]}},$cc[0].",".$cc[1];

	$cc[0]=~/(CL\d+)\_(L\d+)\_(.*)/ or $cc[0]=~/(V\d+)\_(L\d+)\_(.*)/;
	my ($flowcell,$lane,$smp)=($1,$2,$3);
	my $temp="$CalcuDir/$lane\_$smp";
	my $out="$OutDir/$cc[4]/SAMPLES/$cc[2]";
	mkpath("$temp");
	mkpath("$out");

	(open S,">$temp/assembly.sh") || die $!;
	my $FqToAnalysis =$cc[0];

	my ($fq1,$fq2)=($FqToAnalysis."_1.fq.gz",$FqToAnalysis."_2.fq.gz");

        print S "
#!/bin/bash
#\$ -N m_$lane\_$smp
#\$ -cwd
#\$ -pe mpi 16
#\$ -l vf=50G
#\$ -o $temp/assembly.o
#\$ -e $temp/assembly.e

set -e
$FilePath{stLFRPip}/lib/bin/ParseBarcodedFastqs FASTQS=\"{$fq1,$fq2}\" OUT_HEAD=$temp/tmp/reads NUM_THREADS=12 NUM_BUCKETS=$threads
$FilePath{stLFRPip}/lib/bin/DF ROOT=$temp/tmp LR=$temp/tmp/reads.fastb PIPELINE=cs ALIGN=False NUM_THREADS=$threads MAX_MEM_GB=$maxmem 
$FilePath{stLFRPip}/lib/bin/CP DIR=$temp/tmp/GapToy/1/a.base NUM_THREADS=$threads MAX_MEM_GB=$maxmem
$FilePath{stLFRPip}/lib/bin/MakeFasta DIR=$temp/tmp/GapToy/1/a.base/final FLAVOR=pseudohap OUT_HEAD=$temp/tmp/original

zcat $temp/tmp/original.fasta.gz | sed -e \"s/ /_/g\" \>$temp/tmp/original_underscore.fasta

$FilePath{stLFRPip}/bin/bwa index $temp/tmp/original_underscore.fasta
$FilePath{stLFRPip}/bin/bwa mem -t $threads $temp/tmp/original_underscore.fasta $fq1 $fq2 > $temp/tmp/ForSamtools.sam
$FilePath{stLFRPip}/bin/samtools view -Sb $temp/tmp/ForSamtools.sam > $temp/tmp/original.bam
rm $temp/tmp/ForSamtools.sam

$FilePath{stLFRPip}/bin/bamsort I=$temp/tmp/original.bam O=$temp/tmp/original_sort.bam blockmb=\$( expr 1024 \\* $maxmem ) sortthreads=$threads
$FilePath{stLFRPip}/bin/bammarkduplicates I=$temp/tmp/original_sort.bam O=$temp/tmp/original_sort_mdp.bam markthreads=$threads index=1

$FilePath{stLFRPip}/bin/minimap2 -x asm10 $temp/tmp/original_underscore.fasta $temp/tmp/original_underscore.fasta > $temp/tmp/overlap.paf
$FilePath{stLFRPip}/lib/bin/ReScaffold FASTA_IN=$temp/tmp/original_underscore.fasta BAM_IN=$temp/tmp/original_sort_mdp.bam PAF_IN=$temp/tmp/overlap.paf LWML_IN=$temp/tmp/GapToy/1/a.base/records/lwml FASTA_OUT=$temp/output.fasta
#Copy Result
mkdir -p $out
ln -s $temp/output.fasta $out/$flowcell\_$lane.fasta

echo GoodRun!! > $temp/$smp.sign
";
	close S;
	
	print QSUB "qsub $temp/assembly.sh\n";
}
close QSUB;


