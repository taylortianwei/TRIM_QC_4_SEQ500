use strict;
use Data::Dumper;
use File::Path;

if(@ARGV < 3){
	print "perl $0 <fastq files record> <project id> <outdir>\n";
	exit(0);
}
my $fqfile=shift;
my $pjid=shift;
my $out=shift; $out="$out";
my $ftp="/ftp";

(open FQ,$fqfile) || die $!;
open QSUB,">$out/FTP_FQ.sh";
my %to_cp;
while(<FQ>){
	chomp;
	my @cc=split;

	my $smp_id=$cc[2];
	push @{$to_cp{$smp_id}},$cc[0];
}
foreach my $id(keys %to_cp){
	my @fqs=@{$to_cp{$id}};
	foreach my $fq(@fqs){
		my @ccc=split(/\//,$fq);
		print QSUB "mkdir -p $ftp/$pjid/Raw_Fastq/$id\n";
		print QSUB "cp $fq\_1.fq.gz $fq\_2.fq.gz $ftp/$pjid/Raw_Fastq/$id\n";
		print QSUB "md5sum $fq\_1.fq.gz > $ftp/$pjid/Raw_Fastq/$id/$ccc[-1]\_1.fq.gz.md5\n";
		print QSUB "md5sum $fq\_2.fq.gz > $ftp/$pjid/Raw_Fastq/$id/$ccc[-1]\_2.fq.gz.md5\n";
	}
}
close QSUB;
