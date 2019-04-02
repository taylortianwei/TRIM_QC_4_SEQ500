use strict;
use Data::Dumper;
use File::Path;

if(@ARGV < 3){
	print "perl $0 <fastq files record> <outdir> <prefix>\n";
	exit ;
}
my $fqfile=shift;
my $OutDir=shift;
my $CalcuDir=shift;

my $ReferenceFile="/share/Data01/tianwei/Database/id_genome.list";
my $RefLength="/share/Data01/tianwei/Database/id_chrlength.list";
my $Ref=&get_ref($ReferenceFile);
my $Len=&get_ref($RefLength);

(open FQ,$fqfile) || die $!;

my %rlID_bcID;
mkpath("$CalcuDir");

open QSUB,">$CalcuDir/qsub_mapping.sh";
while(<FQ>){
	chomp;
	my @cc=split(/\t/);
	my $species=$cc[1];
	push @{$rlID_bcID{$cc[4]."/".$cc[2]}},$cc[0].",".$cc[1];

	$cc[0]=~/(CL\d+)\_(L\d+)\_(.*)/ or $cc[0]=~/(V\d+)\_(L\d+)\_(.*)/;
	my ($flowcell,$lane,$smp)=($1,$2,$3);
	my $temp="$CalcuDir/$lane\_$smp";
	my $out="$OutDir/$cc[4]/SAMPLES/$cc[2]";
	mkpath("$temp");
	mkpath("$out");

	(open S,">$temp/map.sh") || die $!;
	my $TestContent="no";
	my $ToTest="$CalcuDir/../3_QualityFilter";
	my $TestContent=`cat $ToTest/$flowcell\_$lane\_$smp\_fqc.sign` if -e "$ToTest/$flowcell\_$lane\_$smp\_fqc.sign"; chomp $TestContent;
	my $FqToAnalysis =$cc[0];
        $FqToAnalysis="$ToTest/$flowcell\_$lane\_$smp/Clean_$flowcell\_$lane\_$smp" if $TestContent =~ /Success!!/;

	my ($fq1,$fq2)=($FqToAnalysis."_1.fq.gz",$FqToAnalysis."_2.fq.gz");

	my $Parameter;
	if(-e $fq1){
		$Parameter="
/share/Data01/tianwei/projects/bin/bwa-0.7.12/bwa aln -o 1 -e 50 -m 100000 -t 4 -i 15 -q 10 -f $temp/1.sai $Ref->{$species} $fq1
/share/Data01/tianwei/projects/bin/bwa-0.7.12/bwa aln -o 1 -e 50 -m 100000 -t 4 -i 15 -q 10 -f $temp/2.sai $Ref->{$species} $fq2

/share/Data01/tianwei/projects/bin/bwa-0.7.12/bwa sampe -a 697 -r \"\@RG\\tID:$flowcell\\tPL:BGI\\tPU:131129_I191_FCH7CU0ADXX_$lane\_$flowcell\\tLB:$flowcell\\tSM:V5YH_1\\tCN:BGI\" $Ref->{$species} $temp/1.sai $temp/2.sai $fq1 $fq2 | /share/app/samtools-1.2/bin/samtools view -b -S -T $Ref->{$species} - > $temp/$smp.bam

rm $temp/1.sai $temp/2.sai
"
	}elsif(-e $FqToAnalysis.".fq.gz"){
		$Parameter="
/share/Data01/tianwei/projects/bin/bwa-0.7.12/bwa aln -o 1 -e 50 -m 100000 -t 4 -i 15 -q 10 -f $temp/1.sai $Ref->{$species} $FqToAnalysis.fq.gz

/share/Data01/tianwei/projects/bin/bwa-0.7.12/bwa samse -r \"\@RG\\tID:$flowcell\\tPL:BGI\\tPU:131129_I191_FCH7CU0ADXX_$lane\_$flowcell\\tLB:$flowcell\\tSM:V5YH_1\\tCN:BGI\" $Ref->{$species} $temp/1.sai $FqToAnalysis.fq.gz | /share/app/samtools-1.2/bin/samtools view -b -S -T $Ref->{$species} - > $temp/$smp.bam
rm $temp/1.sai
";
        }else{
                print "Error: the file $fq1 is not exists!\n";
        }

        print S "
#!/bin/bash
#\$ -N m_$lane\_$smp
#\$ -cwd
#\$ -pe mpi 4
#\$ -l virtual_free=100M
#\$ -o $temp/map.o
#\$ -e $temp/map.e

set -e
#mapping
$Parameter

#Copy Result
mkdir -p $out
ln -s $temp/$smp.bam $out/$flowcell\_$lane\_$smp.bam

echo GoodRun!! > $temp/$smp.sign
";
	close S;
	
	print QSUB "qsub $temp/map.sh\n";
}
close QSUB;


sub get_ref
{
	my $in=shift;
	open IN,$in; my %out;
	while(<IN>){
		chomp;
		my @a=split;
		$out{$a[0]}=$a[1];
	}
	return \%out;
}

