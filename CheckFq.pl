use strict;
use Data::Dumper;
use File::Path;
use File::Basename;

if(@ARGV < 1){
	print "perl $0 <fastq files record>\n";
	exit(1);
}
my $fqfile=shift;
my $Log="/opt/sharefolder/05.BGIAU-Bioinformatics/LogFiles/RunProject.txt";

(open FQ,$fqfile) || die $!;

open LOG, ">>$Log";
my $datestring = localtime();
print LOG "Time: $datestring\n";

my $flowcell;
while(<FQ>){
	chomp;
	my @cc=split(/\t/);
	
	$cc[0]=~/(Zebra\d+)\/(CL\d+)/ or $cc[0]=~/(Panda\d+)\/(V\d+)/;
        $flowcell=$cc[3].":".join("_",$1,$2);
	if(-e $cc[0]."_1.fq.gz"){
		my $file=`less $cc[0]\_1.fq.gz| head -n 2`;
		my ($FqName,$FqSeq)=split(/\n/,$file);
		unless (length($FqSeq) == $cc[4]){
			print "$cc[3]: FASTQ Length Wrong: $cc[0]\_1.fq.gz is ".length($FqSeq).", but your CSV says $cc[4]\n";
			exit(1);
		}
	}else{
		print "$cc[3]: FASTQ NOT EXIST: $cc[0]\_1.fq.gz etc.\n";
		exit(1);
	}
	if (-e $cc[0]."_2.fq.gz"){
		my $file=`less $cc[0]\_2.fq.gz| head -n 2`;
                my ($FqName,$FqSeq)=split(/\n/,$file);
		unless (length($FqSeq) == $cc[5]){
                        print "$cc[3]: FASTQ Length Wrong: $cc[0]\_2.fq.gz is ".length($FqSeq).", but your CSV says $cc[5]\n";
                        exit(1);
                }
	}
	#Out Log
	print LOG "$_\n";
}
print "Good Run: $flowcell\n";
