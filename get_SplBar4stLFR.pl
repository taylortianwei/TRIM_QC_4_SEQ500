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

if(@ARGV < 1){
	print "perl $0 <fastq files record>\n";
	exit(0);
}
my $fqfile=shift;

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
	my $out=join("/",@cc[0..7]);
	
	next if $to_cal{$cc[7]};
	
	mkpath($out);
	open SH,">$out/SplitBarcode.sh";
        print SH "
#!/bin/bash
#\$ -N SBR\_$cc[6]\_$cc[7]
#\$ -cwd
#\$ -pe mpi 10
#\$ -l h_vmem=10G
#\$ -l virtual_free=100M
#\$ -l h_rt=72:00:00
#\$ -o $out/SplitBarcode.o
#\$ -e $out/SplitBarcode.e

set -e
time=\$(date \"+%Y%m%d-%H:%M:%S\")
echo \"BEGIN \${time}\"

perl $FilePath{stLFRPip}/split_barcode/split_barcode_PEXXX_42_unsort_reads.pl $FilePath{Bar4stLFR}.list $FilePath{Bar4stLFR}\_RC.list $in\_1.fq.gz $in\_2.fq.gz $aa[7] $aa[0]
echo \"$aa[0]\_1.fq.gz\" > $aa[0].lane.lst
echo \"$aa[0]\_2.fq.gz\" >> $aa[0].lane.lst

$FilePath{stLFRPip}/split_barcode/SOAPfilter_v2.2 -t 50 -q 33 -y -F CTGTCTCTTATACACATCTTAGGAAGACAAGCACTGACGACATGATCACCAAGGATCGCCATAGTCCATGCTAAAGGACGTCAGGAAGGGCGATCTCAGG -R TCTGCTGAGTCGAGAACGTCTCTGTGAGCCAAGGAGTTGCTCTGGCGACGGCCACGAAGCTAACAGCCAATCTGCGTAACAGCCAAACCTGAGATCGCCC -p -M 2 -f -1 -Q 10 $aa[0].lane.lst $aa[0].stat.txt 1> $aa[0].log 2> $aa[0].err

perl -e '\@A;\$n=-1; while(<>){\$n++;chomp;\@t=split; for(\$i=0;\$i<\@t;\$i++){\$A[\$n][\$i]=\$t[\$i]; }} for(\$i=0;\$i<\@t;\$i++){print \"\$A[0][\$i]\\t\$A[1][\$i]\\n\";}' $aa[0].stat.txt >$aa[0].stat.csv

time=\$(date \"+%Y%m%d-%H:%M:%S\")
echo \"END: \${time}\"
echo \"GoodRun\" > $out/SplitBarcode.sign
";
	$to_cal{$cc[7]}=1;
}
