use strict;
use Data::Dumper;
use POSIX;
use File::Path;

my $record="/share/fileshare/BGI_LAB/TRACKING_DOCUMENT/8SampleSheet/CSV";
my $bakup="/share/fileshare/report/CSV_Backup";
my $output="/share/fileshare/report/Result";
my $CalcuDir="/share/Data01/tianwei/FASTQC";
my $datadir="/share";
my $rpath="/share/app/R-3.2.1/bin/Rscript";

my %check;
while(1){

	#make a copy
	my $year_month_day=strftime("%Y%m%d",localtime());
	system("cp -r $record $bakup/$year_month_day");
	#check Record file
	foreach my $file(<$output/*>){
		$file=~s/$output\/*//;
		next unless $file=~/(Zebra\d+_CL\d+)/ or $file=~/(Panda\d+_V\d+)/;
		$check{$1}=1;
	}


	opendir D_R,$record || die "$!";
	foreach my $ff(readdir D_R){
		next unless $ff=~/^(Zebra\d+)\_(CL\d+)\_.*\.csv$/i or $ff=~/^(Panda\d+)\_(V\d+)\_.*\.csv$/i;
		my($zebra,$flowcell)=($1,$2);
		next if $check{$zebra."_".$flowcell};
		my %summary; my %fqfiles;
		
		open II,"$record/$ff";
		while(<II>){
			chomp; s/\s+$//g;
			my @a=split(/\,/,$_);

			next unless $a[0] =~/^\d+$/ and $a[5]=~/$flowcell\_(L\d+)\_(.*)/;

			$a[5]=~/$flowcell\_(L\d+)\_(.*)/;
			my ($lane,$smpID)=($1,$2);
			my ($project,$realID,$species,$Fq1Length,$Fq2Length)=@a[1..3,7,8]; $project=~s/\_.*//; $project=~s/\-.*//;
			my $mc_type=$zebra; $mc_type=~s/\d+$//;
			$fqfiles{$project}{"$datadir/$mc_type"."Data01"."/$zebra/$flowcell/$lane/$a[5]\t$species\t$realID\t$project\t$Fq1Length\t$Fq2Length"}=1;

	                opendir DD,"$datadir/$mc_type"."Data01"."/$zebra/$flowcell/$lane/";
	                foreach my $ff(readdir DD){
	                        if ($ff=~/.*?\_(R\d+)\_.*?\.summaryReport\.html/){
	                                $summary{$project}{"$1\_$flowcell\_$lane"}="$datadir/$mc_type"."Data01"."/$zebra/$flowcell/$lane/$ff";
	                        }else{
	                                next;
	                        }
	                }

		}

		# Output FqFiles Record and  one Main file to generate the shells.
		foreach my $project(keys %fqfiles){
			mkpath("$output/".$project."/".$zebra."_".$flowcell) unless -e ("$output/".$project."/".$zebra."_".$flowcell);
			my $tmpout= $output."/".$project."/".$zebra."_".$flowcell;
			open OQ,">$tmpout/fqfiles.txt";
			my $s_fqfiles=$fqfiles{$project};
			foreach my $fq(sort keys %$s_fqfiles){
		        	print OQ "$fq\n";
			}

			open O_SH,">$tmpout/Main.sh" || die $!;
			my $s_summary=$summary{$project};
			print O_SH "#Step1. Backup summary\n";
			print O_SH "mkdir -p $tmpout/1_SUMMARY\n";
                	foreach my $key(sort keys %$s_summary){
                        	print O_SH "cp -r $s_summary->{$key} $tmpout/1_SUMMARY\n";
                	}
			print O_SH "\n#Step2. FASTQC\nmkdir -p $tmpout/2_FASTQC\n";
			print O_SH "perl /share/Data01/tianwei/Bin/TRIM_QC_4_SEQ500/get_fastqc.pl $tmpout/fqfiles.txt $output $CalcuDir $project/$zebra\_$flowcell/2_FASTQC\n";		
			print O_SH "#sh $tmpout/2_FASTQC/qsub.sh\n";

			print O_SH "\n#Step3. Quality Filter\nmkdir -p $tmpout/3_QualityFilter\n";
                        print O_SH "perl /share/Data01/tianwei/Bin/TRIM_QC_4_SEQ500/QC.pl $tmpout/fqfiles.txt $project $output $CalcuDir $project/$zebra\_$flowcell/3_QualityFilter\n";
                        print O_SH "#sh $tmpout/3_QualityFilter/qsub.sh\n";

			print O_SH "\n#Step4. Copy Data to FTP\n";
                        print O_SH "perl /share/Data01/tianwei/Bin/TRIM_QC_4_SEQ500/ftp_FQ.pl $tmpout/fqfiles.txt $project $tmpout $CalcuDir/$project/$zebra\_$flowcell/3_QualityFilter\n";
                        print O_SH "#nohup sh $tmpout/FTP_FQ.sh\n";

			print O_SH "\n#Step5. Mapping and calculation\nperl /share/Data01/tianwei/Bin/TRIM_QC_4_SEQ500/get_alignment.pl $tmpout/fqfiles.txt $output $CalcuDir/$project/$zebra\_$flowcell/4_Alignment\n";
			print O_SH "#sh $CalcuDir/$project/$zebra\_$flowcell/4_Alignment/qsub_mapping.sh\n";

			close O_SH;
		}
	}
	close D_R;
last;
	sleep(5);
}
