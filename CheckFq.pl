use strict;
use Data::Dumper;
use File::Path;
use File::Basename;
use POSIX;
use JSON::XS qw(encode_json decode_json);
use File::Slurp qw(read_file write_file);

if(@ARGV < 1){
	print "perl $0 <fastq files record>\n";
	exit(1);
}
my $fqfile=shift;

my $filerecord="$Bin/FilesHash/Files.hash";
my $json=read_file($filerecord, { binmode => ':raw' });
my %FilePath=%{ decode_json $json };
#print Dumper %FilePath;

open LOG, ">>$FilePath{CheckFq}";
my $time=strftime("%Y%m%d %H:%M:%S",localtime());

my $flowcell;
open FQ,$fqfile;
while(<FQ>){
	chomp;
	my @cc=split(/\t/);
	
	$cc[0]=~/(Zebra\d+)\/(CL\d+)/ or $cc[0]=~/(Panda\d+)\/(V\d+)/;

        $flowcell=$cc[4]."-$cc[5]:".join("_",$1,$2);
	if(-e $cc[0]."_1.fq.gz"){
		my $file=`less $cc[0]\_1.fq.gz| head -n 2`;
		my ($FqName,$FqSeq)=split(/\n/,$file);
		unless (length($FqSeq) == $cc[6]){
			print "$cc[4]-$cc[5]: FASTQ Length Wrong: $cc[0]\_1.fq.gz is ".length($FqSeq).", but your CSV says $cc[6]\n";
			exit(1);
		}
	}elsif(-e $cc[0].".fq.gz"){
		my $file=`less $cc[0].fq.gz| head -n 2`;
                my ($FqName,$FqSeq)=split(/\n/,$file);
		unless (length($FqSeq) == $cc[6]){
                        print "$cc[4]-$cc[5]: FASTQ Length Wrong: $cc[0].fq.gz is ".length($FqSeq).", but your CSV says $cc[6]\n";
                        exit(1);
                }
	}else{
		print "$cc[4]-$cc[5]: FASTQ NOT EXIST: $cc[0]\_1.fq.gz etc.\n";
		exit(1);
	}
	if (-e $cc[0]."_2.fq.gz"){
		my $file=`less $cc[0]\_2.fq.gz| head -n 2`;
                my ($FqName,$FqSeq)=split(/\n/,$file);
		unless (length($FqSeq) == $cc[7]){
                        print "$cc[4]-$cc[5]: FASTQ Length Wrong: $cc[0]\_2.fq.gz is ".length($FqSeq).", but your CSV says $cc[7]\n";
                        exit(1);
                }
	}
	#Out Log
	print LOG "[$time]\t$_\n";
}
print "Good Run: $flowcell\n";
