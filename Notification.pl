use strict;
use Data::Dumper;
use File::Path;

if(@ARGV < 2){
	print "perl $0 <List File> <Email File>\n";
	exit(0);
}
my $fqfile=shift;
my $emails=shift;


(open FQ,$fqfile) || die $!;

my %to_cal;
while(<FQ>){
	chomp;
	my @aa=split(/\t/);
	my @cc=split(/\//,$aa[0]);
	my @dd=split(/\_/,$cc[6]);
	my $MC=$dd[0]; $MC=~s/\d+$//; $MC=$MC."Data01";
	
	$cc[8]=~s/(L\d+).*/$1\_read/;
	my $in=join("/","/share",$MC,@dd,@cc[7,8]);
	my $out=join("/",@cc[0..7]);$out.="_V3";
	
	next if $to_cal{$cc[7]};
	
	mkpath($out);
	my $BarBeg=$aa[7]+1;
	my $BarEnd=$aa[7]+$BarLen;
	open SH,">$out/demultiplexing.sh";
        print SH "
#!/bin/bash
#\$ -N dem\_$cc[6]\_$cc[7]
#\$ -cwd
#\$ -pe mpi 10
#\$ -l h_vmem=10G
#\$ -l virtual_free=100M
#\$ -l h_rt=72:00:00
#\$ -o $out/dem.o
#\$ -e $out/dem.e

set -e
time=\$(date \"+%Y%m%d-%H:%M:%S\")
echo \"BEGIN \${time}\"
#perl /opt/sharefolder/05.BGIAU-Bioinformatics/Bin/DeMultiplexing/BGIAUSVersion/SplitBarcode.pl $barcode $in\_1.fq.gz $in\_2.fq.gz 108 8 1 $out
#perl /opt/sharefolder/05.BGIAU-Bioinformatics/Bin/DeMultiplexing/SplitBarcode/SplitBarcode.pl -b $barcode -r1 $in\_1.fq.gz -r2 $in\_2.fq.gz -e 1 -f $BarBeg -l $BarEnd -o $out
/opt/sharefolder/05.BGIAU-Bioinformatics/Bin/DeMultiplexing/splitBarcode_V0.1.4/V0.1.4_release/linux/splitBarcode $barcode $in\_1.fq.gz -2 $in\_2.fq.gz -b 128 8 1 -o $out -n 10 -m 10 -r
time=\$(date \"+%Y%m%d-%H:%M:%S\")
echo \"END: \${time}\"
echo \"GoodRun\" > $out/demultiplexing.sign
";
	$to_cal{$cc[7]}=1;
}
