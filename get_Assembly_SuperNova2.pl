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

#Copy Result
mkdir -p $out
ln -s $temp/output.fasta $out/$flowcell\_$lane.fasta

echo GoodRun!! > $temp/$smp.sign
";
	close S;
	
	print QSUB "qsub $temp/assembly.sh\n";
}
close QSUB;


