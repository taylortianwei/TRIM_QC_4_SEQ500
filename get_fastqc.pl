use strict;
use Data::Dumper;
use File::Path;

if(@ARGV < 3){
	print "perl $0 <fastq files record> <outdir> <prefix\n";
	exit;
}
my $fqfile=shift;
my $out=shift;
my $temp=shift;
my $prefix=shift;
mkpath("$out/$prefix");
mkpath("$temp/$prefix");

my $Adaptors="/share/Data01/tianwei/Bin/TRIM_QC_4_SEQ500/adaptors.txt";

(open FQ,$fqfile) || die $!;
open QQ,">$out/$prefix/qsub.sh";
#print QQ "cd $temp/$prefix\n";
while(<FQ>){
	chomp;
	my @cc=split(/\t/);
	$cc[0]=~/(CL\d+)\_(L\d+)\_(.*)/ or $cc[0]=~/(V\d+)\_(L\d+)\_(.*)/;
	my ($flowcell,$lane,$smp)=($1,$2,$3);
	(open S,">$temp/$prefix/$flowcell\_$lane\_$smp\_fqc.sh") || die $!;
	my ($fq1,$fq2)=($cc[0]."_1.fq.gz",$cc[0]."_2.fq.gz");
#print "$fq1\n$fq2\n";

        my $Parameter;
        if(-e $fq1){
                $Parameter="-o $temp/$prefix -a $Adaptors $fq1 $fq2";
	}elsif(-e $cc[0].".fq.gz"){
		$Parameter="-o $temp/$prefix -a $Adaptors $cc[0].fq.gz"
        }else{
                die "Error: the file $fq1 is not exists!";
        }


	print S "
#!/bin/bash
#\$ -N fqc_$cc[2]
#\$ -cwd
#\$ -pe mpi 1 
#\$ -l h_vmem=5G
#\$ -l virtual_free=100M
#\$ -l h_rt=72:00:00
#\$ -o $temp/$prefix/$flowcell\_$lane\_$smp\_fqc.o
#\$ -e $temp/$prefix/$flowcell\_$lane\_$smp\_fqc.e

set -e
/share/app/FastQC-0.11.3/fastqc $Parameter

cp $temp/$prefix/*.html $out/$prefix

echo Success!! > $temp/$prefix/$flowcell\_$lane\_$smp\_fqc.sign
";
	close S;
	
	my $ToSee="";
	$ToSee=`cat $temp/$prefix/$flowcell\_$lane\_$smp\_fqc.sign` if -e "$temp/$prefix/$flowcell\_$lane\_$smp\_fqc.sign";	
	unless ($ToSee =~/Success/){
		print QQ "qsub $temp/$prefix/$flowcell\_$lane\_$smp\_fqc.sh\n";
	}
}
close QSUB;
