use strict;
use Data::Dumper;

if(@ARGV <2){
	print "perl $0 <in file> <md5 number> <Noticed Error file>\n";
	exit(1);
}
my $InF=shift;
my $md5=shift;
my $EMessage=shift;

my $FTPmd5=`md5sum $InF`;
$FTPmd5=~s/\s+.*//g;

open MD5,$md5;
my $Rawmd5=<MD5>;
$Rawmd5=~s/\s+.*//g;

if($Rawmd5 ne $FTPmd5){
	open O,">$EMessage";
	print O "$InF: $FTPmd5\n $md5: $Rawmd5\n";
}else{
	print "$InF: $FTPmd5\n $md5: $Rawmd5\n";
}
