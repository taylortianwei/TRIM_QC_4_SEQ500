use strict;
use Data::Dumper;
use File::Path;
use File::Basename;
use POSIX;
use JSON::XS qw(encode_json decode_json);
use File::Slurp qw(read_file write_file);

if(@ARGV < 3){
	print "perl $0 <fastq files record> <Barcode file> <mismatch>\n";
	exit(0);
}
my $fqfile=shift;
my $barcode=shift;
my $mismatch=shift;

open (BC,$barcode) || die $!;
my %BarC;
open OB, ">$barcode.trimed";
while(<BC>){
	chomp;
	my @a=split;
	for(my $i=1;$i<@a;$i++){
		push @{$BarC{$a[0]}},$a[0]."-$i";
		print OB "$a[0]-$i\t$a[$i]\n";
	}
}
close OB;

(open FQ,$fqfile) || die $!;

my %to_cal;
while(<FQ>){
	chomp;
	my @aa=split(/\t/);
	my @cc=split(/\//,$aa[0]);
	my @dd=split(/\_/,$cc[6]);
	my $MC=$dd[0]; $MC=~s/\d+$//; $MC=$MC."Data01";
	
	$cc[8]=~s/(L\d+).*/$1/;
	my $in=join("/","/share",$MC,@dd,$cc[7],$cc[8]."_read");
	my $out=join("/",@cc[0..7]);
	
	next if $to_cal{$cc[7]};
	
	mkpath($out);

	my $MgSH1; my $MgSH2;
	my $RMSH;
	foreach my $k(keys %BarC){
		my @bar=@{$BarC{$k}};
		$MgSH1.="cat "; $MgSH2.="cat ";
		$RMSH.="rm ";
		foreach (@bar){
			$MgSH1.="$out/$cc[8]\_$_\_1.fq.gz ";
			$MgSH2.="$out/$cc[8]\_$_\_2.fq.gz ";
			$RMSH.="$out/$cc[8]\_$_\_*.fq.gz ";
		}
		$MgSH1.="> $out/$cc[8]\_$k\_1.fq.gz\n";
		$MgSH2.="> $out/$cc[8]\_$k\_2.fq.gz\n";
		$RMSH.="\n";
	}

	my $BarBeg=$aa[7]+1;
	my $BarEnd=$aa[7]+$aa[8];
	my $TotalLen=$aa[6]+$aa[7];
	open SH,">$out/demultiplexing.sh";
        print SH "
#!/bin/bash
#\$ -N dem\_$cc[6]\_$cc[7]
#\$ -cwd
#\$ -pe mpi 10
#\$ -l vf=20G
#\$ -l h_rt=72:00:00
#\$ -o $out/dem.o
#\$ -e $out/dem.e

set -e
time=\$(date \"+%Y%m%d-%H:%M:%S\")
echo \"BEGIN \${time}\"
/opt/sharefolder/05.BGIAU-Bioinformatics/Bin/DeMultiplexing/splitBarcode_V0.1.4/V0.1.4_release/linux/splitBarcode $barcode.trimed $in\_1.fq.gz -2 $in\_2.fq.gz -b $TotalLen $aa[8] $mismatch -o $out -n 10 -m 20 -r
$MgSH1
$MgSH2
$RMSH
#perl /opt/sharefolder/05.BGIAU-Bioinformatics/Bin/DeMultiplexing/SplitBarcode/SplitBarcode.pl -b $barcode -r1 $in\_1.fq.gz -r2 $in\_2.fq.gz -e $mismatch -f $BarBeg -l $BarEnd -o $out
time=\$(date \"+%Y%m%d-%H:%M:%S\")
echo \"END: \${time}\"
echo \"GoodRun\" > $out/demultiplexing.sign
";
#	system("qsub $out/demultiplexing.sh");
	$to_cal{$cc[7]}=1;	
}
