use strict;
use Data::Dumper;
use POSIX;
use File::Path;
use FindBin;
use JSON::XS qw(encode_json decode_json);
use File::Slurp qw(read_file write_file);

my $tempdir="$FindBin::Bin/";
my $tempfile="$tempdir/Files.hash";

my $json;
$json=read_file($tempfile, { binmode => ':raw' });
my %FilePath=%{ decode_json $json };
print Dumper %FilePath;

my $logdir="/share/Data01/tianwei/LogFiles";
my %FilePath=(
record=>"/opt/sharefolder/04.BGIAU-Lab/TRACKING_DOCUMENT/8SampleSheet/CSV",
#output=>"/opt/sharefolder/05.BGIAU-Bioinformatics/Result",
datadir=>"/share",
#record=>"/opt/sharefolder/05.BGIAU-Bioinformatics/ForTestCSV",
output=>"/opt/sharefolder/05.BGIAU-Bioinformatics/ResultTest",
#datadir=>"/share/Data01/tianwei/FASTQC",
bakup=>"/opt/sharefolder/05.BGIAU-Bioinformatics/CSV_Backup",
CalcuDir=>"/share/Data01/tianwei/FASTQC",
CopyDir=>"/share/Data01/tianwei/Local2Cloud",
TmpDir=>"/share/Data01/tianwei/tmp",
rpath=>"/share/app/R-3.2.1/bin/Rscript",
NDN=>"/opt/sharefolder/05.BGIAU-Bioinformatics/NewDataNotify",
barcodefile=>"/opt/sharefolder/05.BGIAU-Bioinformatics/Bin/DeMultiplexing/BarcodeInfo.txt",
Bar4stLFR=>"/share/Data01/tianwei/Bin/stLFRDenovo/SuperPlus/split_barcode/barcode",
stLFRPip=>"/share/Data01/tianwei/Bin/stLFRDenovo/SuperPlus",
ftp=>"/ftp",
## Log Files
"CheckFq" => "$logdir/RunProject.log",
"ExternalTracking" => "$logdir/ExternalTracking.log",
"InternalTracking" => "$logdir/InternalTracking.log",
"PrepareHtmlList" => "$logdir/PrepareHtmlList.log",
"CopyFTQ" => "$logdir/FTPRecord.log",
"Monitor" => "$logdir/MonitorRecord.log",
"DepMismatch" => 1,
"Adaptor5" => "TTGTCTTCCTAAGGAACGACATGGCTACGATCCGACTT",
"Adaptor3" => "AGTCGGAGGCCAAGCGGTCTTAGGAAGACAA",
## Email
tianwei=>"tianwei\@genomics.cn",
yangbicheng=>"yangbicheng\@genomics.cn",
lynn=>"lynnfink\@genomics.cn",
ivon=>"ivonharliwong\@genomics.cn",
cheryll=>"cheryllye\@genomics.cn",
shinan=>"shinan\@genomics.cn",
Avis=>"shiuwingin\@genomics.cn",
## Machines
Zebra01=>"Zebra01",
Zebra02=>"Zebra02",
Zebra03=>"Zebra03",
Panda01=>"Panda01/R100400180045",
#Panda01=>"Panda01",
Panda02=>"Panda02/R100400180107"
);

$json = encode_json \%FilePath;
write_file($tempfile, { binmode => ':raw' }, $json);
