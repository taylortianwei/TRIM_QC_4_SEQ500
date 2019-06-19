use strict;
use Data::Dumper;
use FindBin;
use POSIX;
use JSON::XS qw(encode_json decode_json);
use File::Slurp qw(read_file write_file);


my $Bin=$FindBin::Bin;

if(@ARGV < 1){
	print "perl $0 <Error File>\n";
	exit(1);
}
my $EFile=shift;

my $filerecord="$Bin/FilesHash/Files.hash";
my $json=read_file($filerecord, { binmode => ':raw' });
my %FileHash=%{ decode_json $json };

my %EmailList;
#my @EmailList=("yangbicheng","lynn","tianwei","ivon","cheryll","shinan","Avis");
my @EmailList=("ivon","cheryll","tianwei");

for(my $i=0;$i<@EmailList;$i++){
	if($i < 2){
		$EmailList{CC}.="\"$FileHash{$EmailList[$i]}\",";
	}else{
		$EmailList{TO}.="\"$FileHash{$EmailList[$i]}\",";
	}
}

my %ToEmail;

if((stat "$EFile")[7] ){
	local $/;
	open my $fh, '<', $EFile or die "can't open $EFile: $!\n";
	my $var =<$fh>; $var=~s/\n.*?has been submitted//g;
	$var=~s/\n/\\n/g;

	open O,">$EFile.py";
	$EmailList{CC}=~s/\,$/\]/;
	$EmailList{TO}=~s/\,$/\]/;
	print O "
#!/usr/bin/python
# -*- coding: UTF-8 -*-

import smtplib
from email.mime.text import MIMEText
from email.header import Header

tolist=[$EmailList{TO}
cclist=[$EmailList{CC}

msg = MIMEText(\"$var\", 'plain', 'utf-8')

from_addr = \"bgi-auslab\@genomics.cn\"
passwd = \"Ti-bG0Ax\"
msg['To']=\",\".join(tolist)
msg['Cc']=\",\".join(cclist)
msg['Subject']=Header(u'ErrorMessage while Monitoring, Please Check!!','utf-8').encode()

s = smtplib.SMTP('mail.genomics.cn')
s.starttls()
s.login(from_addr, passwd)
s.sendmail(from_addr, tolist + cclist, msg.as_string())
s.quit()
";
system("python $EFile.py ");
system("rm $EFile.py ");
}
