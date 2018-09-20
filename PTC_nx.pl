use strict;
use Data::Dumper;

my $in=shift;
open IN,$in;
while(<IN>){
	if(/## METRICS CLASS/){
		my $title=<IN>; chomp $title;
		my $table=<IN>; chomp $table;
		my @title=split(/\s+/,$title);
		my @table=split(/\s+/,$table);
		for(my $i=0;$i<@table;$i++){
			next unless $title[$i]=~/PCT_\d+X/;
			print "$title[$i]\t$table[$i]\n";
		}
	}
}
