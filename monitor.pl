use strict;
use Data::Dumper;
use POSIX;
use File::Path;
use FindBin;

my $Bin=$FindBin::Bin;

my $record="/opt/sharefolder/04.BGIAU-Lab/TRACKING_DOCUMENT/8SampleSheet/CSV";
my $bakup="/opt/sharefolder/05.BGIAU-Bioinformatics/CSV_Backup";
my $output="/opt/sharefolder/05.BGIAU-Bioinformatics/Result";
my $CalcuDir="/share/Data01/tianwei/FASTQC";
my $CopyDir="/share/Data01/tianwei/Local2Cloud";
my $datadir="/share";
my $rpath="/share/app/R-3.2.1/bin/Rscript";

my %check;
while(1){

	#make a copy
	my $year_month_day=strftime("%Y%m%d",localtime());
	system("cp -r $record $bakup/$year_month_day");
	#check Record file
	foreach my $file(<$output/*/*>){
		$file=~s/.*(Zebra\d+_CL\d+|Panda\d+_V\d+)/$1/;
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

			next unless $a[5]=~/$flowcell\_(L\d+)\_(.*)/ and $a[0]=~/^1|2|3|4/;

			$a[5]=~/$flowcell\_(L\d+)\_(.*)/;
			my ($lane,$smpID)=($1,$2);
			#my ($project,$subproject,$RunStatus,$realID,$species,$Fq1Length,$Fq2Length)=@a[10..12,1,3,7,8];
			my ($project,$realID,$species,$Fq1Length,$Fq2Length)=@a[1,1,3,7,8];$project=~s/\_.*//; $project=~s/\-.*//;

                        my $mc_type=$zebra; $mc_type=~s/\d+$//;
			#next unless $RunStatus eq "COMPLETE";
			my $mc_type=$zebra; $mc_type=~s/\d+$//;
			my $data="Data01";
			unless (-e "$datadir/$mc_type$data/$zebra/$flowcell/$lane/$a[5]\_1.fq.gz"){
				$data="Data00";
			}
			$fqfiles{$project}{"$datadir/$mc_type$data/$zebra/$flowcell/$lane/$a[5]\t$species\t$realID\t$project\t$Fq1Length\t$Fq2Length"}=1;

	                opendir DD,"$datadir/$mc_type$data/$zebra/$flowcell/$lane/";
	                foreach my $sf(readdir DD){
	                        if ($sf=~/summaryReport\.html/){
	                                $summary{$project}{"$1\_$flowcell\_$lane"}="$datadir/$mc_type$data/$zebra/$flowcell/$lane/$sf";
	                        }else{
	                                next;
	                        }
	                }

		}
		# Output FqFiles Record and  one Main file to generate the shells.
		next if scalar(keys %fqfiles) == 0;
		foreach my $project(keys %fqfiles){
			$flowcell.="_BADRUN" if $ff=~/BAD/i;
			mkpath("$output/".$project."/".$zebra."_".$flowcell) unless -e ("$output/".$project."/".$zebra."_".$flowcell);
			my $tmpout= $output."/".$project."/".$zebra."_".$flowcell;
			open OQ,">$tmpout/fqfiles.txt";
			my $s_fqfiles=$fqfiles{$project};
			foreach my $fq(sort keys %$s_fqfiles){
		        	print OQ "$fq\n";
			}

			open O_SH,">$tmpout/Main.sh" || die $!;
			my $s_summary=$summary{$project};
			print O_SH "set -e \n#Check FQ files\n";
			print O_SH "perl $Bin/CheckFq.pl $tmpout/fqfiles.txt\n";
			print O_SH "#Step1. Backup summary\n";
			print O_SH "mkdir -p $tmpout/1_SUMMARY\n";
                	foreach my $key(sort keys %$s_summary){
                        	print O_SH "cp -r $s_summary->{$key} $tmpout/1_SUMMARY\n";
                	}
			print O_SH "\n#Step2. FASTQC\nmkdir -p $tmpout/2_FASTQC\n";
			print O_SH "perl $Bin/get_fastqc.pl $tmpout/fqfiles.txt $output $CalcuDir $project/$zebra\_$flowcell/2_FASTQC\n";		
			print O_SH "#sh $tmpout/2_FASTQC/qsub.sh\n";

			print O_SH "\n#Step3. Quality Filter\nmkdir -p $tmpout/3_QualityFilter\n";
                        print O_SH "perl $Bin/get_trimFQ.pl $tmpout/fqfiles.txt $project $output $CalcuDir $project/$zebra\_$flowcell/3_QualityFilter\n";
                        print O_SH "#sh $tmpout/3_QualityFilter/qsub.sh\n";

			print O_SH "\n#Step4. Copy Data to FTP\n";
                        print O_SH "perl $Bin/ftp_FQ.pl $tmpout/fqfiles.txt $project $tmpout $CalcuDir/$project/$zebra\_$flowcell/3_QualityFilter\n";
                        print O_SH "#nohup sh $tmpout/FTP_FQ.sh\n";

			print O_SH "\n#Step5. Backup Data to Cloud\n#copy data login: aus-login-1-2 192.168.233.14\n";
                        print O_SH "perl $Bin/copydata.pl $tmpout/fqfiles.txt $CopyDir $zebra\_$flowcell\n";
                        print O_SH "#nohup sh $CopyDir/$zebra\_$flowcell/Main.sh\n";

			print O_SH "\n#Step6. Mapping and calculation\nperl $Bin/get_alignment.pl $tmpout/fqfiles.txt $output $CalcuDir/$project/$zebra\_$flowcell/4_Alignment\n";
			print O_SH "#sh $CalcuDir/$project/$zebra\_$flowcell/4_Alignment/qsub_mapping.sh\n";

			close O_SH;
		}
	}
	close D_R;
last;
	sleep(5);
}
