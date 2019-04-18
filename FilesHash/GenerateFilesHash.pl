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
#record=>"/opt/sharefolder/04.BGIAU-Lab/TRACKING_DOCUMENT/8SampleSheet/CSV"
record=>"/opt/sharefolder/05.BGIAU-Bioinformatics/ForTestCSV",
bakup=>"/opt/sharefolder/05.BGIAU-Bioinformatics/CSV_Backup",
output=>"/opt/sharefolder/05.BGIAU-Bioinformatics/ResultTest",
CalcuDir=>"/share/Data01/tianwei/FASTQC",
CopyDir=>"/share/Data01/tianwei/Local2Cloud",
datadir=>"/share",
rpath=>"/share/app/R-3.2.1/bin/Rscript",
NDN=>"/opt/sharefolder/05.BGIAU-Bioinformatics/NewData",
barcodefile=>"/opt/sharefolder/05.BGIAU-Bioinformatics/Bin/DeMultiplexing/BarcodeInfo.txt",
ftp=>"/ftp",
"CheckFq" => "$logdir/RunProject.log",
"ExternalTracking" => "$logdir/ExternalTracking.log",
"InternalTracking" => "$logdir/InternalTracking.log",
"PrepareHtmlList" => "$logdir/PrepareHtmlList.log",
"CopyFTQ" => "$logdir/FTPRecord.log",
"Monitor" => "$logdir/MonitorRecord.log"
);

$json = encode_json \%FilePath;
write_file($tempfile, { binmode => ':raw' }, $json);
