use strict;
use Data::Dumper;
use POSIX;
use File::Path;
use FindBin;
use JSON::XS qw(encode_json decode_json);
use File::Slurp qw(read_file write_file);

my $Bin=$FindBin::Bin;

my $filerecord="$Bin/FilesHash/Files.hash";
my $json=read_file($filerecord, { binmode => ':raw' });
my %FilePath=%{ decode_json $json };

my $time=strftime("%Y%m%d %H:%M:%S",localtime());

my %check;
#make a copy
my $year_month_day=strftime("%Y%m%d",localtime());

system("cp -r $FilePath{record} $FilePath{bakup}/$year_month_day");
#check Record file
foreach my $file(<$FilePath{output}/*/*/*>){
	my @a=split(/\//,$file);
	next if $a[6] eq "SAMPLES";
	if($a[7]=~/BADLANE/){
		$check{$a[7]}=1;
	}else{
		next unless $a[7]=~s/.*(Zebra\d+_CL\d+|Panda\d+_V\d+).*/$1/;
		$check{$a[7]}=1;
	}
}
#print Dumper %check;

my $data="Data01";

opendir D_R,$FilePath{record} || die "$!";
foreach my $ff(readdir D_R){
	next unless $ff=~/^(Zebra\d+)\_(CL\d+)\_.*\.csv$/i or $ff=~/^(Panda\d+)\_(V\d+)\_.*\.csv$/i;
	my($zebra,$flowcell)=($1,$2);
	next if $check{$zebra."_".$flowcell};

	my %OutPut;
        open $OutPut{Log},">>$FilePath{Monitor}" unless $OutPut{Log};
	my %summary; my %fqfiles;my %projects; my %BadFQ; my %main; my %lanes; my %DeMultiplex;

	open II,"$FilePath{record}/$ff"; my %C_Status;
	my $Skip="[$ff] NO Lane Info\n";
	while(<II>){
		chomp; s/\s+$//g;
		my @a=split(/\,/,$_);

		next unless $a[5]=~/$flowcell\_(L\d+)\_(.*)/ and $a[0]=~/^1|2|3|4/;
		$Skip=0;

		$a[0]="L0".$a[0];
		foreach my $i(1,2,3,7,10,11,12){
			if($a[$i] eq ""){
				$Skip="[$ff] NO Value after $a[$i-1] in:\n$_\n" unless ($a[6] eq "stLFR");
			}
		}
	
		$a[8]=0 if $a[8] eq "";

                my $mc_type=$zebra; $mc_type=~s/\d+$//;
		if($a[12] eq "BADRUN_INCOMPLETE" or $a[12] eq "BADRUN_COMPLETE_UNUSABLE"){
			if($a[6] eq "NoDemultiplexing"){
				$BadFQ{$a[5]."|$a[1]"}="NODEM";
				$projects{$a[5]."|$a[1]"}=[@a[10..12,1..3,7,8,9,0]];
			}else{
				if ($BadFQ{$a[5]}){
                        	        $Skip="[$ff] Duplex value for : $a[5]\n";
                        	}else{
                        	        $BadFQ{$a[5]}="NOFQ";
                        	}
				$projects{$a[5]}=[@a[10..12,1..3,7,8,9,0]];
			}
			$C_Status{BADRUN}=1;
		}elsif($a[6] eq "NoDemultiplexing"){
			opendir DD,"$FilePath{datadir}/$mc_type$data/$zebra/$flowcell/$a[0]/";
                        foreach my $sf(readdir DD){
                                if ($sf=~/summaryReport\.html/){
                                         $summary{$flowcell}{$a[0]}="$FilePath{datadir}/$mc_type$data/$zebra/$flowcell/$a[0]/$sf";
                                }else{
                                        next;
                                }
                        }

			$a[5]=~s/read/$a[4]/;
			$fqfiles{$a[5]}="$FilePath{CalcuDir}/DeMultiplex/$zebra\_$flowcell/$a[0]";
			$projects{$a[5]}=[@a[10..12,1..3,7,8,9,0]];
			$DeMultiplex{$a[5]}=join("|",@a[10,11]);
			$C_Status{GOODRUN}=1;
			$main{$a[10]}{$a[11]}=1;
			$lanes{$a[10]}{$a[11]}{$a[0]}=1;
		}elsif($a[6] eq "stLFR"){
			opendir DD,"$FilePath{datadir}/$mc_type$data/$zebra/$flowcell/$a[0]/";
                        foreach my $sf(readdir DD){
                                if ($sf=~/summaryReport\.html/){
                                         $summary{$flowcell}{$a[0]}="$FilePath{datadir}/$mc_type$data/$zebra/$flowcell/$a[0]/$sf";
                                }else{
                                        next;
                                }
                        }

			$a[5]=~s/(L\d+)\_/$1\_Splited\_/;
			$fqfiles{$a[5]}="$FilePath{CalcuDir}/stLFR/$zebra\_$flowcell/$a[0]";
			$projects{$a[5]}=[@a[10..12,1..3,7,8,9,0]];
                        $DeMultiplex{$a[5]}=join("|",@a[10,11]);
                        $C_Status{GOODRUN}=1;
                        $main{$a[10]}{$a[11]}=2;
			$lanes{$a[10]}{$a[11]}{$a[0]}=2;
		}else{
			my $check=&CheckFQ("$FilePath{datadir}/$mc_type$data/$zebra/$flowcell/$a[0]/$a[5]",$a[7],$a[8]);
			if($check eq "GOOD"){
				opendir DD,"$FilePath{datadir}/$mc_type$data/$zebra/$flowcell/$a[0]/";
                                foreach my $sf(readdir DD){
                                        if ($sf=~/summaryReport\.html/){
                                                $summary{$flowcell}{$a[0]}="$FilePath{datadir}/$mc_type$data/$zebra/$flowcell/$a[0]/$sf";
                                        }else{
                                                next;
                                        }
                                }

				if ($fqfiles{$a[5]}){
                                        $Skip="[$ff] Duplex value for : $a[5]\n";
                                }else{
                                        $main{$a[10]}{$a[11]}=0;
					$lanes{$a[10]}{$a[11]}{$a[0]}=0;
                                        $fqfiles{$a[5]}="$FilePath{datadir}/$mc_type$data/$zebra/$flowcell/$a[0]";
                                }
				$C_Status{GOODRUN}=1;
			}elsif($check eq "NOFQ"){
				$BadFQ{$a[5]}=$check;
				$C_Status{BADRUN}=1;
			}else{
				$BadFQ{$a[5]}=$check;
				$C_Status{GOODRUN}=1;
			}
			$projects{$a[5]}=[@a[10..12,1..3,7,8,9,0]];
		}
	}	
	if ($Skip ne 0){
		print $Skip;next;
	}
	#print Dumper %projects;
	#print Dumper %fqfiles;
	#print Dumper %C_Status;
	#print Dumper %BadFQ;
	#print Dumper %OutPut;

	foreach my $_FLB(sort keys %projects){
		my ($proj,$subproj,$RunStatus,$realID,$SubmitID,$species,$Fq1Length,$Fq2Length,$Fq3Length,$lane)=@{$projects{$_FLB}};
		my $mc_type=$zebra; $mc_type=~s/\d+$//;
		
		if($fqfiles{$_FLB}){
			mkpath("$FilePath{output}/".$proj."/".$subproj."/".$zebra."_".$flowcell) unless -e ("$FilePath{output}/".$proj."/".$subproj."/".$zebra."_".$flowcell);
			open $OutPut{fqfiles}{"$proj|$subproj|$flowcell"},">>$FilePath{output}/$proj/$subproj/$zebra\_$flowcell/fqfiles.txt" unless $OutPut{fqfiles}{"$proj|$subproj|$flowcell"};
			print {$OutPut{fqfiles}{"$proj|$subproj|$flowcell"}} join("\t","$fqfiles{$_FLB}/$_FLB",$species,$realID,$SubmitID,$proj,$subproj,$Fq1Length,$Fq2Length,$Fq3Length),"\n";
			## Log Files
			print {$OutPut{Log}} join("\t","[$time]\t","$FilePath{output}/".$proj."/".$subproj."/".$zebra."_".$flowcell),"\n";
			## Let us know new data generating
			mkpath("$FilePath{NDN}/$year_month_day") unless -e "$FilePath{NDN}/$year_month_day";
			open $OutPut{Notify}{$year_month_day."G"},">>$FilePath{NDN}/$year_month_day/SampleInfo.xls" unless $OutPut{Notify}{$year_month_day."G"};
			&NotiFy("$fqfiles{$_FLB}",$proj,$subproj,$_FLB,$zebra."_".$flowcell,$FilePath{NDN},$year_month_day,$realID,$SubmitID,\%OutPut);
		}elsif($BadFQ{$_FLB}){
			if($BadFQ{$_FLB} =~/^WL:(.*)/){
				print "[$ff] READ LENGTH ISSUE: $FilePath{datadir}/$mc_type$data/$zebra/$flowcell/$lane/$_FLB\_1.fq.gz is $1, but $Fq1Length|$Fq2Length in CSV\n";
			}elsif($BadFQ{$_FLB} eq "FQNotE"){
				print "[$ff] NO FILE EXISTS: $FilePath{datadir}/$mc_type$data/$zebra/$flowcell/$lane/$_FLB\_1.fq.gz\n";
			}elsif($BadFQ{$_FLB} eq "NODEM"){
				my $status="BADRUN"; $status="BADLANE" if keys %C_Status > 1;
				mkpath("$FilePath{output}/".$proj."/".$subproj."/".$zebra."_".$flowcell."_".$status) unless -e ("$FilePath{output}/".$proj."/".$subproj."/".$zebra."_".$flowcell."_".$status);
				open $OutPut{fqfiles}{"$proj|$subproj|$flowcell"},">>$FilePath{output}/$proj/$subproj/$zebra\_$flowcell\_$status/fqfiles.txt" unless $OutPut{fqfiles}{"$proj|$subproj|$flowcell"};
                                my $mc_type=$zebra; $mc_type=~s/\d+$//;
				$_FLB=~s/\|.*//;
                                print {$OutPut{fqfiles}{"$proj|$subproj|$flowcell"}} join("\t","$FilePath{datadir}/$mc_type$data/$zebra/$flowcell/$lane/$_FLB",$species,$realID,$SubmitID,$proj,$subproj,$Fq1Length,$Fq2Length,$Fq3Length),"\n";
				print {$OutPut{Log}} join("\t","[$time]\t","$FilePath{output}/".$proj."/".$subproj."/".$zebra."_".$flowcell."_".$status),"\n";
				mkpath("$FilePath{NDN}/$year_month_day") unless -e "$FilePath{NDN}/$year_month_day";
				open $OutPut{Notify}{$year_month_day."B"},">>$FilePath{NDN}/$year_month_day/BadRunsInfo.xls" unless $OutPut{Notify}{$year_month_day."B"};
                                &NotiFy("BADRUN",$proj,$subproj,$_FLB,$zebra."_".$flowcell,$FilePath{NDN},$year_month_day,$realID,$SubmitID,\%OutPut);
			}elsif($BadFQ{$_FLB} eq "NOFQ"){
				my $status="BADRUN"; $status="BADLANE" if keys %C_Status > 1;
				mkpath("$FilePath{output}/".$proj."/".$subproj."/".$zebra."_".$flowcell."_".$status) unless -e ("$FilePath{output}/".$proj."/".$subproj."/".$zebra."_".$flowcell."_".$status);
                        	my $mc_type=$zebra; $mc_type=~s/\d+$//;

				open $OutPut{fqfiles}{"$proj|$subproj|$flowcell"},">>$FilePath{output}/$proj/$subproj/$zebra\_$flowcell\_$status/fqfiles.txt" unless $OutPut{fqfiles}{"$proj|$subproj|$flowcell"};
                        	print {$OutPut{fqfiles}{"$proj|$subproj|$flowcell"}} join("\t","$FilePath{datadir}/$mc_type$data/$zebra/$flowcell/$lane/$_FLB",$species,$realID,$SubmitID,$proj,$subproj,$Fq1Length,$Fq2Length,$Fq3Length),"\n";
				print {$OutPut{Log}} join("\t","[$time]\t","$FilePath{output}/".$proj."/".$subproj."/".$zebra."_".$flowcell."_".$status),"\n";
				mkpath("$FilePath{NDN}/$year_month_day") unless -e "$FilePath{NDN}/$year_month_day";
				open $OutPut{Notify}{$year_month_day."B"},">>$FilePath{NDN}/$year_month_day/BadRunsInfo.xls" unless $OutPut{Notify}{$year_month_day."B"};
				&NotiFy("BADRUN",$proj,$subproj,$_FLB,$zebra."_".$flowcell,$FilePath{NDN},$year_month_day,$realID,$SubmitID,\%OutPut);
			}else{
				print "[$ff] is wrong!! please check\n";
			}
		}else{
			print "[$ff] is wrong!! please check\n";
		}
	}
	foreach my $ForDeMut(sort keys %DeMultiplex){
		my @a=split;my @b=split(/\|/,$a[1]);
		
	}
	foreach my $p(keys %main){
		my $TmpHash=$main{$p};
		foreach my $subp(keys %$TmpHash){
			my $LibType=$TmpHash->{$subp};

			my $tmpout="$FilePath{output}/$p/$subp/$zebra\_$flowcell";
			my $shell=&MainShell($Bin,$FilePath{output},$FilePath{CalcuDir},$FilePath{CopyDir},$tmpout,$p,$subp,$zebra,$flowcell,$summary{$flowcell},$LibType,$lanes{$p}{$subp});		
			open $OutPut{MainSH}{"$p|$subp|$flowcell"},">$FilePath{output}/$p/$subp/$zebra\_$flowcell/Main.sh" unless $OutPut{MainSH}{"$p|$subp|$flowcell"};
			print {$OutPut{MainSH}{"$p|$subp|$flowcell"}} $shell;
			## Run everything
			system ("nohup sh $tmpout/Main.sh");
	
			## Log Files
			print {$OutPut{Log}} join("\t","[$time]\t","$FilePath{output}/".$p."/".$subp."/".$zebra."_".$flowcell),"\n";
		}
	}
}
close D_R;

sub CheckFQ
{
	my ($fq,$l1,$l2)=@_;
	
	my $check="FQNotE";
	if(-e $fq."_1.fq.gz"){
		my $file1=`less $fq\_1.fq.gz | head -n 2`;
		my $file2=`less $fq\_2.fq.gz | head -n 2`;
		my $FqSeq1=(split(/\n/,$file1))[1];
		my $FqSeq2=(split(/\n/,$file2))[1];
		if(length($FqSeq1) > 0){
                	if(length($FqSeq1) == $l1 and length($FqSeq2) == $l2){
				$check="GOOD";
                	}else{
				$check="WL:".length($FqSeq1)."|".length($FqSeq2);
			}
		}else{
			$check="NOFQ";
		}
	}elsif(-e $fq.".fq.gz"){
                my $file=`less $fq.fq.gz | head -n 2`;
                my ($FqName,$FqSeq)=split(/\n/,$file);
		if(length($FqSeq) > 0){
                	if(length($FqSeq) == $l1){
                	        $check="GOOD";
                	}else{
                	        $check="WL:".length($FqSeq)."|0";
                	}
		}else{
			$check="NOFQ";
		}
        }
	return $check;
}

sub MainShell
{
	my ($Bin,$output,$CalcuDir,$CopyDir,$tmpout,$p,$subp,$zebra,$flowcell,$s_summary,$LibType,$lanes)=@_;
	mkpath("$output/".$p."/".$subp."/".$zebra."_".$flowcell) unless -e ("$output/".$p."/".$subp."/".$zebra."_".$flowcell);
	my $shell="#Step1. Backup summary\nmkdir -p $tmpout/1_SUMMARY\n";
	if($LibType == 0){
        	foreach my $key(sort keys %$lanes){
        	        $shell.="cp -r $s_summary->{$key} $tmpout/1_SUMMARY\n";
        	}
        	$shell.="
#Step2. FASTQC\nmkdir -p $tmpout/2_FASTQC
perl $Bin/get_fastqc.pl $tmpout/fqfiles.txt $output $CalcuDir $p/$subp/$zebra\_$flowcell/2_FASTQC
sh $tmpout/2_FASTQC/qsub.sh

#Step3. Quality Filter\nmkdir -p $tmpout/3_QualityFilter
#perl $Bin/get_trimFQ.pl $tmpout/fqfiles.txt $p/$subp $output $CalcuDir $p/$subp/$zebra\_$flowcell/3_QualityFilter
#sh $tmpout/3_QualityFilter/qsub.sh

#Step4. Copy Data to FTP
perl $Bin/ftp_FQ.pl $tmpout/fqfiles.txt $p/$subp $tmpout $CalcuDir/$p/$subp/$zebra\_$flowcell/3_QualityFilter
#nohup sh $tmpout/FTP_FQ.sh

#Step5. Backup Data to Cloud\n#copy data login: aus-login-1-2 192.168.233.14
#perl $Bin/copydata.pl $tmpout/fqfiles.txt $CopyDir $zebra\_$flowcell
#nohup sh $CopyDir/$zebra\_$flowcell/Main.sh

#Step6. Mapping and calculation
#perl $Bin/get_alignment.pl $tmpout/fqfiles.txt $output $CalcuDir/$p/$subp/$zebra\_$flowcell/4_Alignment
#sh $CalcuDir/$p/$subp/$zebra\_$flowcell/4_Alignment/qsub_mapping.sh
";
	}elsif($LibType == 1){
		my $DemShell="#Step2. Demultiplexing
perl $Bin/get_demultiplexing.pl $tmpout/fqfiles.txt $FilePath{barcodefile} $FilePath{DepMismatch}
";
		my $check;
                foreach my $key(sort keys %$lanes){
                        $shell.="cp -r $s_summary->{$key} $tmpout/1_SUMMARY\n";
			
			$DemShell.="qsub $CalcuDir/DeMultiplex/$zebra\_$flowcell/$key/demultiplexing.sh" unless -e "$CalcuDir/DeMultiplex/$zebra\_$flowcell/$key/demultiplexing.sign";
			$check.=" -f $CalcuDir/DeMultiplex/$zebra\_$flowcell/$key/demultiplexing.sign &&";
                }
		$check=~s/\&\&$//;
		$shell.="
$DemShell

until [[$check]]
do
	sleep 600
done

#Step3. FASTQC
mkdir -p $tmpout/2_FASTQC
perl $Bin/get_fastqc.pl $tmpout/fqfiles.txt $output $CalcuDir $p/$subp/$zebra\_$flowcell/2_FASTQC
sh $tmpout/2_FASTQC/qsub.sh

#Step4. Quality Filter\nmkdir -p $tmpout/3_QualityFilter
perl $Bin/get_trimFQ.pl $tmpout/fqfiles.txt $p/$subp $output $CalcuDir $p/$subp/$zebra\_$flowcell/3_QualityFilter
#sh $tmpout/3_QualityFilter/qsub.sh

#Step5. Copy Data to FTP
perl $Bin/ftp_FQ.pl $tmpout/fqfiles.txt $p/$subp $tmpout $CalcuDir/$p/$subp/$zebra\_$flowcell/3_QualityFilter
#nohup sh $tmpout/FTP_FQ.sh

#Step6. Backup Data to Cloud\n#copy data login: aus-login-1-2 192.168.233.14
#perl $Bin/copydata.pl $tmpout/fqfiles.txt $CopyDir $zebra\_$flowcell
#nohup sh $CopyDir/$zebra\_$flowcell/Main.sh

#Step7. Mapping and calculation
#perl $Bin/get_alignment.pl $tmpout/fqfiles.txt $output $CalcuDir/$p/$subp/$zebra\_$flowcell/4_Alignment
#sh $CalcuDir/$p/$subp/$zebra\_$flowcell/4_Alignment/qsub_mapping.sh
";
	}elsif($LibType == 2){
		my $DemShell="#Step2. SplitBarcode for stLFR
perl $Bin/get_SplBar4stLFR.pl $tmpout/fqfiles.txt $FilePath{Bar4stLFR}
";
                my $check;
                foreach my $key(sort keys %$lanes){
                        $shell.="cp -r $s_summary->{$key} $tmpout/1_SUMMARY\n";

                        $DemShell.="qsub $CalcuDir/stLFR/$zebra\_$flowcell/$key/SplitBarcode.sh" unless -e "$CalcuDir/stLFR/$zebra\_$flowcell/$key/SplitBarcode.sign";
                        $check.=" -f $CalcuDir/stLFR/$zebra\_$flowcell/$key/SplitBarcode.sign &&";
                }
                $check=~s/\&\&$//;
		$shell.="
$DemShell

until [[$check]]
do
        sleep 600
done

#Step3. FASTQC
mkdir -p $tmpout/2_FASTQC
perl $Bin/get_fastqc.pl $tmpout/fqfiles.txt $output $CalcuDir $p/$subp/$zebra\_$flowcell/2_FASTQC
sh $tmpout/2_FASTQC/qsub.sh

#Step4. Quality Filter\nmkdir -p $tmpout/3_QualityFilter
perl $Bin/get_trimFQ.pl $tmpout/fqfiles.txt $p/$subp $output $CalcuDir $p/$subp/$zebra\_$flowcell/3_QualityFilter
#sh $tmpout/3_QualityFilter/qsub.sh

#Step5. Copy Data to FTP
perl $Bin/ftp_FQ.pl $tmpout/fqfiles.txt $p/$subp $tmpout $CalcuDir/$p/$subp/$zebra\_$flowcell/3_QualityFilter
#nohup sh $tmpout/FTP_FQ.sh

#Step6. Backup Data to Cloud\n#copy data login: aus-login-1-2 192.168.233.14
#perl $Bin/copydata.pl $tmpout/fqfiles.txt $CopyDir $zebra\_$flowcell
#nohup sh $CopyDir/$zebra\_$flowcell/Main.sh

#Step7. Mapping and calculation
#perl $Bin/get_Assembly4stLFR.pl $tmpout/fqfiles.txt $output $CalcuDir/$p/$subp/$zebra\_$flowcell/4_Assembly
#sh $CalcuDir/$p/$subp/$zebra\_$flowcell/4_Assembly/qsub_assembly.sh
";
	}
	return $shell;
}

sub NotiFy
{
	my($SmpInfo,$p,$subp,$flb,$fcl,$ODir,$time,$RID,$SID,$OutPut)=@_;
	
	mkpath("$ODir/$time/$p") unless -e "$ODir/$time/$p";
	if ($SmpInfo ne "BADRUN"){

		mkpath("$ODir/$time/$p/$RID") unless -e "$ODir/$time/$p/$RID";
		print {$OutPut->{Notify}{$time."G"}} join("\t",$p,$subp,$RID,$SID,$SmpInfo."/$flb*.fq.gz"),"\n";
	}else{
		$fcl=~s/\_.*?$/_$flb/;
		print {$OutPut->{Notify}{$time."B"}} join("\t",$RID,$SID,$fcl),"\n";

	}
}
