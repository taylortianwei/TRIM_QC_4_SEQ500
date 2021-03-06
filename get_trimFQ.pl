use strict;
use Data::Dumper;
use File::Path;
use FindBin;
use JSON::XS qw(encode_json decode_json);
use File::Slurp qw(read_file write_file);

my $Bin=$FindBin::Bin;

my $filerecord="$Bin/FilesHash/Files.hash";
my $json=read_file($filerecord, { binmode => ':raw' });
my %FilePath=%{ decode_json $json };

if(@ARGV < 3){
	print "perl $0 <fastq files record> <outdir> <prefix\n";
	exit;
}
my $fqfile=shift;
my $pjid=shift;
my $out=shift;
my $temp=shift;
my $prefix=shift;

mkpath("$out/$prefix");
mkpath("$temp/$prefix");

(open FQ,$fqfile) || die $!;
open QQ,">$out/$prefix/qsub.sh";
while(<FQ>){
	chomp;
	my @cc=split(/\t/,$_);
	$cc[0]=~/(CL\d+)\_(L\d+)\_(.*)/ or $cc[0]=~/(V\d+)\_(L\d+)\_(.*)/;
	my ($flowcell,$lane,$smp)=($1,$2,$3);
	(open S,">$temp/$prefix/$flowcell\_$lane\_$smp\_qc.sh") || die $!;
	my ($fq1,$fq2)=($cc[0]."_1.fq.gz",$cc[0]."_2.fq.gz");
	my ($Fq1Length,$Fq2Length)=@cc[4,5];
#print "$fq1\n$fq2\n";

	my $Parameter;
	if(-e $fq1){
		my $TmpLengthFq2=length((split(/\n/,`less $fq2 | head`))[1]);
		my $ToTrim=$TmpLengthFq2-$Fq2Length;
		$Parameter="-1 $fq1 -2 $fq2 -Q 2 -f $FilePath{Adaptor5} -r $FilePath{Adaptor3}";
	}elsif(-e $cc[0].".fq.gz"){
		$Parameter="-1 $cc[0].fq.gz -f $FilePath{Adaptor5} -Q 2";
	}else{
		die "Error: the file $fq1 is not exists!";
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
/share/Data01/tianwei/Bin/DNA_CSAP_v5.2.7/bin/SOAPnuke filter $Parameter -o $temp/$prefix/$flowcell\_$lane\_$smp
cp $temp/$prefix/$flowcell\_$lane\_$smp/Basic_Statistics_of_Sequencing_Quality.txt $out/$prefix/Basic_Statistics_of_Sequencing_Quality_$flowcell\_$lane\_$smp.txt
ln -s $temp/$prefix/$flowcell\_$lane\_$smp/Clean_$flowcell\_$lane\_$smp\_1.fq.gz $temp/$prefix/$flowcell\_$lane\_$smp/Clean_$flowcell\_$lane\_$smp\_2.fq.gz $out/$prefix/

echo Success!! > $temp/$prefix/$flowcell\_$lane\_$smp\_fqc.sign
";
	close S;
	
	print QQ "qsub $temp/$prefix/$flowcell\_$lane\_$smp\_qc.sh\n";

}
close QQ;
