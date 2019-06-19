use strict;
use Data::Dumper;
use File::Path;
use File::Basename;
use POSIX;
use JSON::XS qw(encode_json decode_json);
use File::Slurp qw(read_file write_file);
use FindBin;
my $Bin=$FindBin::Bin;

if(@ARGV < 3){
	print "perl $0 <fastq files record> <project id> <outdir>\n";
	exit(0);
}
my $fqfile=shift;
my $pjid=shift;
my $out=shift;
my $ToTest=shift;

my $filerecord="$Bin/FilesHash/Files.hash";
my $json=read_file($filerecord, { binmode => ':raw' });
my %FilePath=%{ decode_json $json };

#print Dumper %FilePath;

(open FQ,$fqfile) || die $!;
open QSUB,">>$out/FTP_FQ.sh";


my %to_cp;
my $SubmitID;
while(<FQ>){
	chomp;
	my @cc=split(/\t/);
	$cc[0]=~/(CL\d+)\_(L\d+)\_(.*)/ or $cc[0]=~/(V\d+)\_(L\d+)\_(.*)/;
        my ($flowcell,$lane,$smp)=($1,$2,$3);

	my $TestContent="no";
	my $TestContent=`cat $ToTest/$flowcell\_$lane\_$smp\_fqc.sign` if -e "$ToTest/$flowcell\_$lane\_$smp\_fqc.sign"; chomp $TestContent;

	my $FqToCopy =$cc[0];

	$SubmitID=$cc[3];
	push @{$to_cp{$cc[2]}},$FqToCopy;
}
foreach my $id(keys %to_cp){
	my @fqs=@{$to_cp{$id}};
	foreach my $fq(@fqs){
		my ($fq1,$fq2)=($fq."_1.fq.gz",$fq."_2.fq.gz");
		my $dir=dirname($fq);
		my @ccc=split(/\//,$fq);
        	if(-e $fq1){
                       	print QSUB "
time=\$(date \"+%Y%m%d %H:%M:%S\")
echo \"[\${time}]	$pjid	$id	$SubmitID	$ccc[-1]	$fq\" >> $FilePath{CopyFTQ} 
";
		}elsif(-e $fq.".fq.gz"){
			print QSUB "
time=\$(date \"+%Y%m%d %H:%M:%S\")
echo \"[\${time}]       $pjid   $id     $SubmitID       $ccc[-1]        $fq\" >> $FilePath{CopyFTQ}
";
        	}else{
                	die "Error: the file $fq is not exists!";
        	}
	}
}
close QSUB;
