use strict;
use Data::Dumper;
use POSIX;
use File::Path;

if(@ARGV < 4){
	die "perl $0 <input file list> <workdir> <R path> <tmp dir>\n";
}
my $namefile=shift;
my $workdir=shift;
my $rpath=shift;
my $tmpdir=shift;

open Rsc_1,">$tmpdir/process2plot_1.txt";
print Rsc_1 join("\t","File","ChipProductivity","Q30","SplitRate","ESR","\n") ; 
open Rsc_2,">$tmpdir/process2plot_2.txt";
print Rsc_2 join("\t","File","Lag","Runon","\n") ;
open Rsc_3,">$tmpdir/process2plot_3.txt";
print Rsc_3 join("\t","File","Lag1","Lag2","Runon1","Runon2","\n") ;

my ($cc,$pc,$files)=&get_hash($namefile);

my @names=("signal","Fig1_Intensity_of_All_DNBs","rho","Fig2_Rho_of_Intensity","trendSignal","Fig3_Trend_of_Intensity","background","Fig4_Background_Intensity","snr","Fig5_SNR","metrics","Fig6_Metrics_of_Bic_and_Fit","esr","Fig7_Effective_Spots_Rate","accGrr","Fig8_Accumulated_Good_Read_Rate","runon","Fig9_Runon","lag","Fig10_Lag","movement","Fig11_Offset_by_Cycles","baseTypeDist","Fig13_Bases_Distribution","gcDist","Fig14_GC_Distribution","estError","Fig15_Error_Rate_Estimation","qual","Fig16_Average_Quality_Distribution");
my @legend_pos=("top","top","top","topleft","topleft","center","topleft","top","topleft","topleft","bottomleft","center","bottomright","top","bottomleft");

my %names=@names;
my %to_R; my %sepe=("SE",0,"PE",0);
foreach (my $i=0;$i<@$files;$i++){
	my $arry=$files->[$i];
print "$arry\n";
	foreach my $kk("ChipProductivity","Q30","SplitRate","ESR"){
                my $val=$cc->{$kk."%"}{$files->[$i]};
                $arry.="\t".$val/100;
        }
        print Rsc_1 "$arry\n";
	if($cc->{"readType"}{$files->[$i]} eq "SE"){
		$arry=$files->[$i];
		foreach my $kk("Lag","Runon"){
			my $val=$cc->{$kk."%"}{$files->[$i]};
			$arry.="\t".$val;
		}
		$sepe{"SE"}=1;
		print Rsc_2 "$arry\n";
	}else{
		$arry=$files->[$i];
		foreach my $kk("Lag1","Lag2","Runon1","Runon2"){
                        my $val=$cc->{$kk."%"}{$files->[$i]};
                        $arry.="\t".$val;
                }
		$sepe{"PE"}=1;
                print Rsc_3 "$arry\n";
	}
	mkpath("$tmpdir/files/$files->[$i]");
	for(my $k=0; $k<@names; $k+=2){
		open O,">$tmpdir/files/$files->[$i]/$names[$k].xls";
		my $to_print=$pc->{$files->[$i]}{$names[$k]};
		print O "$to_print\n";
		push @{$to_R{$names[$k]}},"data<-read.table(\"$tmpdir/files/$files->[$i]/$names[$k].xls\",head=T,row.names=1)
matplot(data, type = \"o\", pch=c(20,20,20,20,20), lty=1,lwd=0.3,cex=0.3, bty=\"l\", mgp=c(1,0.4,0),cex.axis=0.5, main=\"$files->[$i]\",cex.main=0.5, col=c(\"red\",\"green\",\"brown\",\"blue\",\"darkgrey\"), bg = 2:7)
legend(\"$legend_pos[$k/2]\",legend=names(data),pch=c(20,20,20,20,20),lty=1,lwd=0.4,col=c(\"red\",\"green\",\"brown\",\"blue\",\"darkgrey\"),bty=\"n\",cex=0.4)"
	}
}
#my $year_month_day=strftime("%Y%m%d",localtime());
mkpath("$workdir/Others");

for(my $k=0; $k<scalar(@names); $k+=2){
	my $outputdir="$workdir";
	$outputdir="$workdir/Others" unless ($names[$k]=~/signal|background|snr|metrics|esr|movement/);
        open Oo, ">$outputdir/$names{$names[$k]}.R";
	print Oo "pdf(\"$outputdir/$names{$names[$k]}.pdf\")\n";
	print Oo "par(mar = c(1, 1, 2, 1),mfrow = c(4, 4))\n";
	next unless $to_R{$names[$k]};
        my @ffff=@{$to_R{$names[$k]}};
        print Oo join("\n",@ffff,"\n");
        close Oo;
	system "$rpath $outputdir/$names{$names[$k]}.R";
	unlink("$outputdir/$names{$names[$k]}.R");
}
open TS,">$workdir/Table_summary.R";
if($sepe{"SE"}==1 and $sepe{"PE"}==1){
	print TS "pdf(\"$workdir/Table_summary.pdf\")
par(mar = c(4, 1, 2, 1))
layout(matrix(c(1,2,1,3),2,2))

data1<-read.table(\"$tmpdir/process2plot_1.txt\",head=T,row.names=1)
matplot(data1, type = \"o\", pch=c(7,9,12,13), lty=1,lwd=0.5,cex=0.5, ylim=c(0, 1),col=1:10,cex.axis=0.5, cex.main=0.8, mgp=c(1,0.4,0),bg = 2:7,xaxt=\"n\",ylab=\"\",main=\"Table_Summary\")
files=row.names(data1)
axis(1,at=seq(1,nrow(data1),1),label=files,line=-0.8,lwd=0.5,tick = F,cex.axis=0.3,las=3)
legend(\"bottomleft\",legend=names(data1),pch=c(7,9,12,13),lty=1,lwd=0.5,col=1:10,bty=\"n\",cex=0.5)

data2<-read.table(\"$tmpdir/process2plot_2.txt\",head=T,row.names=1)
matplot(data2, type = \"o\", pch=c(6,6), lty=1,lwd=0.5,cex=0.5, ylim=c(0, 0.5),col=c(11,12),bg = 2:7,mgp=c(1,0.4,0),cex.axis=0.5,cex.main=0.8,xaxt=\"n\",ylab=\"\",main=\"Lan_Runon_SE\")
files=row.names(data2)
axis(1,at=seq(1,nrow(data2),1),label=files,line=-0.8,lwd=0.5,tick = F,cex.axis=0.3,las=3)
#position,names,point type,line type,line wide,color same as plot,without square,font size,
legend(\"topleft\",legend=names(data2),pch=c(6,6),lty=1,lwd=0.5,col=c(11,12),bty=\"n\",cex=0.5)

data3<-read.table(\"$tmpdir/process2plot_3.txt\",head=T,row.names=1)
matplot(data3, type = \"o\", pch=c(6,2,6,2), lty=1,lwd=0.5,cex=0.5, ylim=c(0, 0.5),col=c(11,11,12,12),bg = 2:7,mgp=c(1,0.4,0),cex.axis=0.5,cex.main=0.8,ylab=\"\",xaxt=\"n\",main=\"Lan_Runon_PE\")
files=row.names(data3)
axis(1,at=seq(1,nrow(data3),1),label=files,line=-0.8,lwd=0.5,tick = F,cex.axis=0.3,las=3)
legend(\"topleft\",legend=names(data3),pch=c(6,2,6,2),lty=1,lwd=0.5,col=c(11,11,12,12),bty=\"n\",cex=0.5)
";
}elsif($sepe{"SE"}==1 and $sepe{"PE"}==0){
        print TS "pdf(\"$workdir/Table_summary.pdf\")
par(mar = c(4, 1, 2, 1))
layout(matrix(c(1,2,1,2),2,2))

data1<-read.table(\"$tmpdir/process2plot_1.txt\",head=T,row.names=1)
matplot(data1, type = \"o\", pch=c(7,9,12,13), lty=1,lwd=0.5,cex=0.5, ylim=c(0, 1),col=1:10,cex.axis=0.5, cex.main=0.8, mgp=c(1,0.4,0),bg = 2:7,xaxt=\"n\",ylab=\"\",main=\"Table_Summary\")
files=row.names(data1)
axis(1,at=seq(1,nrow(data1),1),label=files,line=-0.8,lwd=0.5,tick = F,cex.axis=0.3,las=3)
#position,names,point type,line type,line wide,color same as plot,without square,font size,
legend(\"bottomleft\",legend=names(data1),pch=c(7,9,12,13),lty=1,lwd=0.5,col=1:10,bty=\"n\",cex=0.5)

data2<-read.table(\"$tmpdir/process2plot_2.txt\",head=T,row.names=1)
matplot(data2, type = \"o\", pch=c(6,6), lty=1,lwd=0.5,cex=0.5, ylim=c(0, 0.5),col=c(11,12),bg = 2:7,mgp=c(1,0.4,0),cex.axis=0.5,cex.main=0.8,xaxt=\"n\",ylab=\"\",main=\"Lan_Runon_SE\")
files=row.names(data2)
axis(1,at=seq(1,nrow(data2),1),label=files,line=-0.8,lwd=0.5,tick = F,cex.axis=0.3,las=3)
legend(\"topleft\",legend=names(data2),pch=c(6,6),lty=1,lwd=0.5,col=c(11,12),bty=\"n\",cex=0.5)
";
}elsif($sepe{"SE"}==0 and $sepe{"PE"}==1){
        print TS "pdf(\"$workdir/Table_summary.pdf\")
par(mar = c(4, 1, 2, 1))
layout(matrix(c(1,2,1,2),2,2))

data1<-read.table(\"$tmpdir/process2plot_1.txt\",head=T,row.names=1)
matplot(data1, type = \"o\", pch=c(7,9,12,13), lty=1,lwd=0.5,cex=0.5, ylim=c(0, 1),col=1:10,cex.axis=0.5, cex.main=0.8, mgp=c(1,0.4,0),bg = 2:7,xaxt=\"n\",ylab=\"\",main=\"Table_Summary\")
files=row.names(data1)
axis(1,at=seq(1,nrow(data1),1),label=files,line=-0.8,lwd=0.5,tick = F,cex.axis=0.3,las=3)
#position,names,point type,line type,line wide,color same as plot,without square,font size,
legend(\"bottomleft\",legend=names(data1),pch=c(7,9,12,13),lty=1,lwd=0.5,col=1:10,bty=\"n\",cex=0.5)

data3<-read.table(\"$tmpdir/process2plot_3.txt\",head=T,row.names=1)
matplot(data3, type = \"o\", pch=c(6,2,6,2), lty=1,lwd=0.5,cex=0.5, ylim=c(0, 0.5),col=c(11,11,12,12),bg = 2:7,mgp=c(1,0.4,0),cex.axis=0.5,cex.main=0.8,ylab=\"\",xaxt=\"n\",main=\"Lan_Runon_PE\")
files=row.names(data3)
axis(1,at=seq(1,nrow(data3),1),label=files,line=-0.8,lwd=0.5,tick = F,cex.axis=0.3,las=3)
legend(\"topleft\",legend=names(data3),pch=c(6,2,6,2),lty=1,lwd=0.5,col=c(11,11,12,12),bty=\"n\",cex=0.5)
";
}
system "$rpath $workdir/Table_summary.R";
unlink("$workdir/Table_summary.R");

sub get_hash
{
	my $file=shift;
	my $hash;
	my $p_hash;
	my @files;

	open FL,$file || die "Error in opening file $file\n";
	while(<FL>){
		my ($fff,$filename)=split;
		open (F,"$fff") || die "Error in opening file $fff\n";
		chomp $filename;
		$filename=~s/.*?\_(R\d+)\_.*/$1/;
		push @files,$filename;
		my $part;
		while (<F>){
			chomp;s/\;.*$//;
			last if /\/\/\s*VALUES\s*END/;
	
			next unless s/^\s+var\s+//; s/\'|\"//g;
			my @c=split(/\=\s+/,$_);
			if($c[0]=~/summaryTable\s/){
				my @matches = ($c[1] =~ /\[(.*?)\]/g);
				foreach my $cc(@matches){
	                		$cc=~s/\[|\]//g;
	                		my @cc=split(/\s*\,\s*/,$cc);
	                		$hash->{$cc[0]}{$filename}=$cc[1];
	        		}		
			}elsif($c[0]=~/readType\s/){
				
				$hash->{readType}{$filename}=$c[1];
			}elsif($c[0]=~/movement\s|signal\s|trendSignal\s|background\s|snr\s|rho\s|metrics\s|esr\s|accGrr\s|runon\s|lag\s|baseTypeDist\s|gcDist\s|estError\s|qual/){
				$c[0]=~s/\s//g;
				$p_hash->{$filename}{$c[0]}=&split_str4($c[1]);
			}
		}
		close F;
	}
	return ($hash,$p_hash,\@files);
}

sub split_str1
{
	my $in=shift;
	my $sub_hash;
	my @matches = ($in =~ /\[(.*?)\]/g);
	foreach my $cc(@matches){
		$cc=~s/\[|\]//g;
		my @cc=split(/\s*\,\s*/,$cc);
		$sub_hash->{$cc[0]}=$cc[1];
	}
	return $sub_hash;
}
sub split_str2
{
        my $in=shift;
        my $sub_hash;
        my @matches = ($in =~ /\[(.*?)\]/g);
	$matches[0]=~s/\[|\]//g; $matches[1]=~s/\[|\]//g;
	for(my $i=1;$i<@matches;$i++){
                my @k=split(/\s*\,\s*/,$matches[$i]);
                push @{$sub_hash->{$k[0]}},@k[1..$#k];
        }
        return $sub_hash;
}
sub split_str3
{
	my $in=shift;
        my $sub_hash;
        my @matches = ($in =~ /\[(.*?)\]/g);
	for(my $i=1;$i<6;$i++){
		my @k=split(/\s*\,\s*/,$matches[$i]);
		push @{$sub_hash->{"Reads1.".$k[0]}},@k[1..$#k];
	}
	if(@matches > 5){
		for(my $j=7;$j<@matches;$j++){
			my @k=split(/\s*\,\s*/,$matches[$j]);
			push @{$sub_hash->{"Reads2.".$k[0]}},@k[1..$#k];
		}
	}
	return $sub_hash;
}
sub split_str4
{
        my $in=shift;
        my $sub_hash;
        my @matches = ($in =~ /(\w+\s*\:\s*\[.*?\]|\[\d+\-\d+\]\s*\:\s*\[.*?\]|\[\d+\-\d+\)\s*\:\s*\[.*?\])/g);
	my @cont;
	foreach (@matches){
		my @tmp_nm=split(/\s*\:\s*/,$_);
		my @number=($tmp_nm[1] =~ /(\-*\d+\.*\d+)\s*/g);
		$cont[0].="\t$tmp_nm[0]";
		foreach (my $i=0; $i<@number; $i++){
			$cont[$i+1].="\t$number[$i]"
		}
	}
	$sub_hash="Pos".$cont[0]."\n";
	for (my $i=1; $i<@cont; $i++){
		$sub_hash.="$i".$cont[$i]."\n";
	}
	return $sub_hash;
}
