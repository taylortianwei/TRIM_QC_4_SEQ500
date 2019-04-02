use strict;
use Data::Dumper;

if(@ARGV < 2){
	print "$0 <copy from> <copy to>\n";
}

my $from=shift;
$from=~s/\/$//;
my $to=shift;

my $files=`du -sh $from/*/*/2_FASTQC`;

my @folders=($files=~/Result(.*?2_FASTQC)/g);

my $time=localtime();
print "####Copy time: $time####\n";
foreach my $fd(@folders){
	unless (-e "$to/$fd"){
		print "From=$from/$fd, To=$to/$fd\n";
		system("cp -r $from/$fd $to/$fd\n");
	}
}
