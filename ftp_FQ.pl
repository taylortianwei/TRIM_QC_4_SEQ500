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

my $kk=shift;
my ($pjid,$subpjid)=split(/\//,$kk);

my $out=shift;
my $ToTest=shift;

my $filerecord="$Bin/../FilesHash/Files.hash";
my $json=read_file($filerecord, { binmode => ':raw' });
my %FilePath=%{ decode_json $json };

#print Dumper %FilePath;

(open FQ,$fqfile) || die $!;
open QSUB,">$out/FTP_FQ.sh";


my %to_cp;
my $SubmitID;
while(<FQ>){
	chomp; next if /^\#/;
	my @cc=split(/\t/);
	$cc[0]=~/(CL\d+)\_(L\d+)\_(.*)/ or $cc[0]=~/(V\d+)\_(L\d+)\_(.*)/ or $cc[0]=~/(S\d+)\_(L\d+)\_(.*)/;
        my ($flowcell,$lane,$smp)=($1,$2,$3);

	my $TestContent="no";
	my $TestContent=`cat $ToTest/$flowcell\_$lane\_$smp\_fqc.sign` if -e "$ToTest/$flowcell\_$lane\_$smp\_fqc.sign"; chomp $TestContent;

	my $FqToCopy =$cc[0];
	$FqToCopy="$ToTest/$flowcell\_$lane\_$smp/Clean_$flowcell\_$lane\_$smp" if $TestContent eq "Success!!";

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
#copy data login: aus-login-1-2 192.168.233.14

mkdir -p $FilePath{ftp}/$pjid/Raw_Fastq/$subpjid/$id
cp $fq\_1.fq.gz $FilePath{ftp}/$pjid/Raw_Fastq/$subpjid/$id
md5sum $fq\_1.fq.gz | perl -ne 's/(\\s+).*\\//\$1/;print' > $FilePath{ftp}/$pjid/Raw_Fastq/$subpjid/$id/$ccc[-1]\_1.fq.gz.md5
cp $fq\_2.fq.gz $FilePath{ftp}/$pjid/Raw_Fastq/$subpjid/$id
md5sum $fq\_2.fq.gz | perl -ne 's/(\\s+).*\\//\$1/;print' > $FilePath{ftp}/$pjid/Raw_Fastq/$subpjid/$id/$ccc[-1]\_2.fq.gz.md5
perl $Bin/check_md5.pl $FilePath{ftp}/$pjid/Raw_Fastq/$subpjid/$id/$ccc[-1]\_1.fq.gz $FilePath{ftp}/$pjid/Raw_Fastq/$subpjid/$id/$ccc[-1]\_1.fq.gz.md5 $FilePath{ftp}/$pjid/Raw_Fastq/$subpjid/$id/$ccc[-1]\_1.fq.gz.md5.err
perl $Bin/check_md5.pl $FilePath{ftp}/$pjid/Raw_Fastq/$subpjid/$id/$ccc[-1]\_2.fq.gz $FilePath{ftp}/$pjid/Raw_Fastq/$subpjid/$id/$ccc[-1]\_2.fq.gz.md5 $FilePath{ftp}/$pjid/Raw_Fastq/$subpjid/$id/$ccc[-1]\_2.fq.gz.md5.err
if [[ -f $FilePath{ftp}/$pjid/Raw_Fastq/$subpjid/$id/$ccc[-1]\_1.fq.gz.md5.err || -f $FilePath{ftp}/$pjid/Raw_Fastq/$subpjid/$id/$ccc[-1]\_1.fq.gz.md5.err ]]; then
	exit 1
fi
time=\$(date \"+%Y%m%d %H:%M:%S\")
echo \"[\$USER][\${time}]	$pjid	$id	$SubmitID	$ccc[-1]	$fq\" >> $FilePath{CopyFTQ} 
";
			if(-e "$dir/Basic_Statistics_of_Sequencing_Quality.txt"){
				print QSUB "
cp $dir/Basic_Statistics_of_Sequencing_Quality.txt $FilePath{ftp}/$pjid/Raw_Fastq/$subpjid/$id/$ccc[-1].FilterStatistics.txt
";
			}
		}elsif(-e $fq.".fq.gz"){
			print QSUB "
mkdir -p $FilePath{ftp}/$pjid/Raw_Fastq/$id
cp $fq.fq.gz $FilePath{ftp}/$pjid/Raw_Fastq/$subpjid/$id
md5sum $fq.fq.gz | perl -ne 's/(\\s+).*\\//\$1/;print' > $FilePath{ftp}/$pjid/Raw_Fastq/$subpjid/$id/$ccc[-1].fq.gz.md5
time=\$(date \"+%Y%m%d %H:%M:%S\")
echo \"[\$USER][\${time}]       $pjid   $id     $SubmitID       $ccc[-1]        $fq\" >> $FilePath{CopyFTQ}
";
			if(-e "$dir/Basic_Statistics_of_Sequencing_Quality.txt"){
				print QSUB "
cp $dir/Basic_Statistics_of_Sequencing_Quality.txt $FilePath{ftp}/$pjid/Raw_Fastq/$subpjid/$id/$ccc[-1].FilterStatistics.txt
";
			}
        	}else{
                	die "Error: the file $fq is not exists!";
        	}
	}
}
close QSUB;
