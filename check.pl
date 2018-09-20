use strict;
use POSIX;
use Data::Dumper;

if(@ARGV < 2){
	die "perl $0 <Fq data folder> <Records>\n";
}

my $workdir=shift;
my $record=shift;

opendir DIR,$record || die "$!";
my $ck_hash=&readhash("$record/LaneInfo.txt");

open RCD,">>$record/LaneInfo.txt";
my %summary; my %fqfiles;
foreach my $file(readdir DIR){
	chomp;
	next unless $file=~/\.csv/;
	next if $ck_hash->{"$record/$file"};

	$file=~/(Zebra\d+)\_(CL\d+)/;
#Zebra02_CL100034677_SampleSheet.csv
	my($flowcell,$zebra)=($1,$2);

	open II,"$record/$file";
	while(<II>){
		chomp;
		my @a=split(/\//,$_);
		next unless /$flowcell\_(L\d+)\_(\d+)/;
		my ($lane,$smpID)=($1,$2);
		opendir DD,"$workdir/$zebra/$flowcell/$lane/";
		foreach my $ff(readdir DD){
			if ($ff=~/.*?\_(R\d+)\_.*?\.summaryReport\.html/){
				$summary{"$1\_$flowcell\_$lane"}="$workdir/$zebra/$flowcell/$lane/$ff";
			}elsif($ff=~s/$flowcell\_$lane\_$smpID\_\d+\.fq\.gz/$flowcell\_$lane\_$smpID/){
				$fqfiles{"$workdir/$zebra/$flowcell/$lane/$ff"}=1;
			}else{
				next;
			}
		}
	}
	
	my $year_month_day=strftime("%Y%m%d",localtime());
	print RCD "$record/$file\t$year_month_day\n";
	$ck_hash->{"$record/$file"}=1;
}

open OS,">$record/summary.txt";
foreach my $key(sort keys %summary){
	print OS "$summary{$key}\t$key\n";
}
close OS;

open OQ,">$record/fqfiles.txt";
foreach my $fq(sort keys %fqfiles){
	print OQ "$fq\n";
}

sub readhash
{
	my $in=shift;
	my $hash;
	
	open IN,$in;
	while(<IN>){
		chomp;
		my @c=split;
		$hash->{$c[0]}=1;
	}
	return $hash;
}
