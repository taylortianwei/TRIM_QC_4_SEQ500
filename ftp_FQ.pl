use strict;
use Data::Dumper;
use File::Path;

if(@ARGV < 3){
	print "perl $0 <fastq files record> <project id> <outdir>\n";
	exit(0);
}
my $fqfile=shift;
my $pjid=shift;
my $out=shift;
my $ToTest=shift;
my $ftp="/ftp";

(open FQ,$fqfile) || die $!;
open QSUB,">$out/FTP_FQ.sh";
my %to_cp;
while(<FQ>){
	chomp;
	my @cc=split;
	$cc[0]=~/(CL\d+)\_(L\d+)\_(.*)/ or $cc[0]=~/(V\d+)\_(L\d+)\_(.*)/;
        my ($flowcell,$lane,$smp)=($1,$2,$3);

	my $TestContent="no";
	my $TestContent=`cat $ToTest/$flowcell\_$lane\_$smp\_fqc.sign` if -e "$ToTest/$flowcell\_$lane\_$smp\_fqc.sign"; chomp $TestContent;

	my $FqToCopy =$cc[0];
	$FqToCopy="$ToTest/$flowcell\_$lane\_$smp/Clean_$flowcell\_$lane\_$smp" if $TestContent eq "Success!!";

	push @{$to_cp{$cc[2]}},$FqToCopy;
}
foreach my $id(keys %to_cp){
	my @fqs=@{$to_cp{$id}};
	foreach my $fq(@fqs){
		my ($fq1,$fq2)=($fq."_1.fq.gz",$fq."_2.fq.gz");
        	if(-e $fq1){
			my @ccc=split(/\//,$fq);
                	if (-e $fq2){
                       		print QSUB "
mkdir -p $ftp/$pjid/Raw_Fastq/$id
cp $fq\_1.fq.gz $ftp/$pjid/Raw_Fastq/$id
md5sum $fq\_1.fq.gz > $ftp/$pjid/Raw_Fastq/$id/$ccc[-1]\_1.fq.gz.md5
cp $fq\_2.fq.gz $ftp/$pjid/Raw_Fastq/$id
md5sum $fq\_2.fq.gz > $ftp/$pjid/Raw_Fastq/$id/$ccc[-1]\_2.fq.gz.md5
";
                	}else{
				print QSUB "
mkdir -p $ftp/$pjid/Raw_Fastq/$id
cp $fq\_1.fq.gz $ftp/$pjid/Raw_Fastq/$id
md5sum $fq\_1.fq.gz > $ftp/$pjid/Raw_Fastq/$id/$ccc[-1]\_1.fq.gz.md5
";
                	}
        	}else{
                	die "Error: the file $fq1 is not exists!";
        	}
	}
}
close QSUB;
