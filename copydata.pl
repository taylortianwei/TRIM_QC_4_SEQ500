use strict;
use Data::Dumper;
use File::Path;

if(@ARGV < 3){
	print "perl $0 <fastq files record> <outdir> <FlowCell>\n";
	exit;
}
my $fqfile=shift;
my $out=shift;
my $M_FC=shift;

mkpath("$out/$M_FC");

(open FQ,$fqfile) || die $!;
open QQ,">$out/$M_FC/Main.sh";
while(<FQ>){
	chomp; my @cc=split(/\t/);
	my ($machine,$flowcell,$lane,$shell)=(split(/\//,$cc[0]))[3,4,5,6];
	(open S,">$out/$M_FC/$shell\_cp.sh") || die $!;
	my ($fq1,$fq2)=($cc[0]."_1.fq.gz",$cc[0]."_2.fq.gz");

	print S "

#copy data login: aus-login-1-2 192.168.233.14
set -e
/share/Data01/tianwei/cloudfile -f $fq1 -P $machine/$flowcell/$lane -k BGIAUS -u
/usr/bin/md5sum $fq1 > $out/$M_FC/$shell\_1.md5
/share/Data01/tianwei/cloudfile -f $out/$M_FC/$shell\_1.md5 -P $machine/$flowcell/$lane -k BGIAUS -u

/share/Data01/tianwei/cloudfile -f $fq2 -P $machine/$flowcell/$lane -k BGIAUS -u
/usr/bin/md5sum $fq2 > $out/$M_FC/$shell\_2.md5
/share/Data01/tianwei/cloudfile -f $out/$M_FC/$shell\_2.md5 -P $machine/$flowcell/$lane -k BGIAUS -u

echo Success!! > $out/$M_FC/$shell\_copy.sign
";
	close S;
	
	print QQ "sh $out/$M_FC/$shell\_cp.sh\n";

}
close QQ;
