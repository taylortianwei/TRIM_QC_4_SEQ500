use strict;
use Data::Dumper;
use File::Path;

if(@ARGV < 3){
	print "perl $0 <fastq files record> <outdir> <prefix>\n";
	exit ;
}
my $fqfile=shift;
my $out=shift;
my $prefix=shift;

my $ReferenceFile="/share/Data01/tianwei/Database/id_genome.list";
my $RefLength="/share/Data01/tianwei/Database/id_chrlength.list";
my $temp="/share/Data01/tianwei/FASTQC/TEMP/$prefix";
my $Ref=&get_ref($ReferenceFile);
my $Len=&get_ref($RefLength);

(open FQ,$fqfile) || die $!;
mkpath("$temp");
mkpath("$out/$prefix/");

my %rlID_bcID;
open QSUB,">$temp/qsub_step1.sh";
while(<FQ>){
	chomp;
	my @cc=split;
	my $species=$cc[1];
	push @{$rlID_bcID{$cc[2]}},$cc[0].",".$cc[1];

	$cc[0]=~/(CL\d+)\_(L\d+)\_(.*)/ or $cc[0]=~/(V\d+)\_(L\d+)\_(.*)/;
	my ($flowcell,$lane,$smp)=($1,$2,$3);
	mkpath("$temp/$flowcell/$lane/$smp");
	mkpath("$out/$prefix/$lane");
	(open S,">$temp/$flowcell/$lane/$smp/map_$smp.sh") || die $!;
	
	my ($fq1,$fq2)=($cc[0]."_1.fq.gz",$cc[0]."_2.fq.gz");
	(open Rsc,">$temp/$flowcell/$lane/$smp/$smp.cov.chr.R") || die $!;
                print Rsc &generate_R("$temp/$flowcell/$lane/$smp",$smp);
        close Rsc;

	if(-e $fq2){
	print S "
!/bin/bash
#\$ -N m_$lane\_$smp
#\$ -cwd
#\$ -pe mpi 4
#\$ -l virtual_free=100M
#\$ -o $temp/$flowcell/$lane/$smp/map_$smp.o
#\$ -e $temp/$flowcell/$lane/$smp/map_$smp.e

set -e
#mapping
#/share/Data01/tianwei/projects/bin/bwa-0.7.12/bwa aln -o 1 -e 50 -m 100000 -t 4 -i 15 -q 10 -f $temp/$flowcell/$lane/$smp/1.sai $Ref->{$species} $fq1
#/share/Data01/tianwei/projects/bin/bwa-0.7.12/bwa aln -o 1 -e 50 -m 100000 -t 4 -i 15 -q 10 -f $temp/$flowcell/$lane/$smp/2.sai $Ref->{$species} $fq2

#/share/Data01/tianwei/projects/bin/bwa-0.7.12/bwa sampe -a 697 -r \"\@RG\\tID:$flowcell\\tPL:BGI\\tPU:131129_I191_FCH7CU0ADXX_$lane\_$flowcell\\tLB:$flowcell\\tSM:V5YH_1\\tCN:BGI\" $Ref->{$species} $temp/$flowcell/$lane/$smp/1.sai $temp/$flowcell/$lane/$smp/2.sai $fq1 $fq2 | /share/app/samtools-1.2/bin/samtools view -b -S -T $Ref->{$species} - > $temp/$flowcell/$lane/$smp/$smp.bam
#rm $temp/$flowcell/$lane/$smp/1.sai $temp/$flowcell/$lane/$smp/2.sai

#/share/app/samtools-1.2/bin/samtools view -h $temp/$flowcell/$lane/$smp/$smp.bam | awk \'\{if \(\!\/\^\@\/ \&\& and\(\$2,4\) \=\= 4\) \{\$5=0\; \$6=\"\*\"\;\} gsub\(\/ \/\,\"\\t\"\,\$0\)\; print\}\' \| /share/app/samtools-1.2/bin/samtools view -b -S -T  $Ref->{$species} - > $temp/$flowcell/$lane/$smp/$smp.bf.bam
#/share/Data01/lynn/projects/bin/java/jdk1.8.0_144/bin/java  -Xmx2G -Djava.io.tmpdir=/share/Data01/tianwei/tmp/java_tmp/ -XX:MaxPermSize=512m -XX:-UseGCOverheadLimit -jar /share/Data01/tianwei/Bin/picard/FixMateInformation.jar I=$temp/$flowcell/$lane/$smp/$smp.bf.bam O=$temp/$flowcell/$lane/$smp/$smp.bftmp.bam SO=coordinate VALIDATION_STRINGENCY=SILENT

#sort
#/share/app/samtools-1.2/bin/samtools calmd -b $temp/$flowcell/$lane/$smp/$smp.bftmp.bam $Ref->{$species} > $temp/$flowcell/$lane/$smp/$smp.sort.bam

#duplication
#/share/Data01/lynn/projects/bin/java/jdk1.8.0_144/bin/java  -Xmx2G -Djava.io.tmpdir=/share/Data01/tianwei/tmp/java_tmp/ -XX:MaxPermSize=512m -XX:-UseGCOverheadLimit -jar /share/Data01/tianwei/Bin/picard/MarkDuplicates.jar MAX_FILE_HANDLES=1000 REMOVE_DUPLICATES=false \\
#I=$temp/$flowcell/$lane/$smp/$smp.sort.bam O=$temp/$flowcell/$lane/$smp/$smp.sort.rmdup.bam \\
#METRICS_FILE=$temp/$flowcell/$lane/$smp/$flowcell\_$lane\_$smp.dup.xls VALIDATION_STRINGENCY=SILENT
#/share/app/samtools-1.2/bin/samtools index $temp/$flowcell/$lane/$smp/$smp.sort.rmdup.bam
#rm $temp/$flowcell/$lane/$smp/$smp.bam $temp/$flowcell/$lane/$smp/$smp.bf.bam $temp/$flowcell/$lane/$smp/$smp.bftmp.bam $temp/$flowcell/$lane/$smp/$smp.sort.bam

#plot
#/share/Data01/lynn/projects/bin/java/jdk1.8.0_144/bin/java  -Xmx2G -Djava.io.tmpdir=/share/Data01/tianwei/tmp/java_tmp/ -XX:MaxPermSize=512m -XX:-UseGCOverheadLimit -jar /share/Data01/tianwei/Bin/TRIM_QC_4_SEQ500/qcmg/qprofiler-1.0.jar --log $temp/$flowcell/$lane/$smp/$smp.cov.chr.log --loglevel INFO --input $temp/$flowcell/$lane/$smp/$smp.sort.rmdup.bam --output $temp/$flowcell/$lane/$smp/$smp.cov.chr.xml
##perl /share/Data01/tianwei/Bin/TRIM_QC_4_SEQ500/parse_chr_data.pl -i $temp/$flowcell/$lane/$smp/$smp.cov.chr.xml > $temp/$flowcell/$lane/$smp/$smp.cov.chr.tsv
#/share/Data01/tianwei/Bin/R-3.3.2/bin/Rscript $temp/$flowcell/$lane/$smp/$smp.cov.chr.R

#mapping stat
#perl /share/Data01/tianwei/Bin/RNA_module/AlignmentStat/AlignmentStat_forBwa/bin/BwaMapStat.pl -bam $temp/$flowcell/$lane/$smp/$smp.sort.rmdup.bam -key $temp/$flowcell/$lane/$smp/$smp.map -samtools /share/app/samtools-1.2/bin/samtools

#insert length calculation
PATH=\$PATH:/share/app/R-3.2.1/bin/
export PATH
/share/Data01/lynn/projects/bin/java/jdk1.8.0_144/bin/java  -Xmx2G -Djava.io.tmpdir=/share/Data01/tianwei/tmp/java_tmp/ -XX:MaxPermSize=512m -XX:-UseGCOverheadLimit -jar /share/Data01/tianwei/Bin/picard/CollectInsertSizeMetrics.jar \\
I=$temp/$flowcell/$lane/$smp/$smp.sort.rmdup.bam \\
O=$temp/$flowcell/$lane/$smp/$smp.Insert.xls \\
H=$temp/$flowcell/$lane/$smp/$smp.Insert.pdf \\
M=0.5

#EstimateLibraryComplexity
/share/Data01/lynn/projects/bin/java/jdk1.8.0_144/bin/java  -Xmx2G -Djava.io.tmpdir=/share/Data01/tianwei/tmp/java_tmp/ -XX:MaxPermSize=512m -XX:-UseGCOverheadLimit -jar /share/app/picard-tools-1.137/picard.jar EstimateLibraryComplexity I=$temp/$flowcell/$lane/$smp/$smp.sort.rmdup.bam O=$temp/$flowcell/$lane/$smp/$smp.libComplexity.xls

#Copy Result
cp $temp/$flowcell/$lane/$smp/$smp.qprofile.ggplot2.pdf $out/$prefix/$lane/$flowcell"."_".$lane."_".$smp.".qprofile.ggplot2.pdf
cp $temp/$flowcell/$lane/$smp/$smp.cov.chr.xml $temp/$flowcell/$lane/$smp/$flowcell\_$lane\_$smp.dup.xls $temp/$flowcell/$lane/$smp/$smp.map*.xls $temp/$flowcell/$lane/$smp/$smp.Insert.xls $temp/$flowcell/$lane/$smp/$smp.Insert.pdf $temp/$flowcell/$lane/$smp/$smp.libComplexity.xls $out/$prefix/$lane/

echo GoodRun!! > $temp/$flowcell/$lane/$smp/$smp.sign
";
	}else{
	 print S "
!/bin/bash
#\$ -N m_$lane\_$smp
#\$ -cwd
#\$ -pe mpi 4
#\$ -l virtual_free=100M
#\$ -o $temp/$flowcell/$lane/$smp/map_$smp.o
#\$ -e $temp/$flowcell/$lane/$smp/map_$smp.e

set -e
#mapping
/share/Data01/tianwei/projects/bin/bwa-0.7.12/bwa aln -o 1 -e 50 -m 100000 -t 4 -i 15 -q 10 -f $temp/$flowcell/$lane/$smp/1.sai $Ref->{$species} $fq1

/share/Data01/tianwei/projects/bin/bwa-0.7.12/bwa samse -r \"\@RG\\tID:$flowcell\\tPL:BGI\\tPU:131129_I191_FCH7CU0ADXX_$lane\_$flowcell\\tLB:$flowcell\\tSM:V5YH_1\\tCN:BGI\" $Ref->{$species} $temp/$flowcell/$lane/$smp/1.sai $fq1 | /share/app/samtools-1.2/bin/samtools view -b -S -T $Ref->{$species} - > $temp/$flowcell/$lane/$smp/$smp.bam
rm $temp/$flowcell/$lane/$smp/1.sai 

/share/app/samtools-1.2/bin/samtools view -h $temp/$flowcell/$lane/$smp/$smp.bam | awk \'\{if \(\!\/\^\@\/ \&\& and\(\$2,4\) \=\= 4\) \{\$5=0\; \$6=\"\*\"\;\} gsub\(\/ \/\,\"\\t\"\,\$0\)\; print\}\' \| /share/app/samtools-1.2/bin/samtools view -b -S -T  $Ref->{$species} - > $temp/$flowcell/$lane/$smp/$smp.bf.bam
/share/Data01/lynn/projects/bin/java/jdk1.8.0_144/bin/java  -Xmx2G -Djava.io.tmpdir=/share/Data01/tianwei/tmp/java_tmp/ -XX:MaxPermSize=512m -XX:-UseGCOverheadLimit -jar /share/Data01/tianwei/Bin/picard/FixMateInformation.jar I=$temp/$flowcell/$lane/$smp/$smp.bf.bam O=$temp/$flowcell/$lane/$smp/$smp.bftmp.bam SO=coordinate VALIDATION_STRINGENCY=SILENT

#sort
/share/app/samtools-1.2/bin/samtools calmd -b $temp/$flowcell/$lane/$smp/$smp.bftmp.bam $Ref->{$species} > $temp/$flowcell/$lane/$smp/$smp.sort.bam

#duplication
/share/Data01/lynn/projects/bin/java/jdk1.8.0_144/bin/java  -Xmx2G -Djava.io.tmpdir=/share/Data01/tianwei/tmp/java_tmp/ -XX:MaxPermSize=512m -XX:-UseGCOverheadLimit -jar /share/Data01/tianwei/Bin/picard/MarkDuplicates.jar MAX_FILE_HANDLES=1000 REMOVE_DUPLICATES=false \\
I=$temp/$flowcell/$lane/$smp/$smp.sort.bam O=$temp/$flowcell/$lane/$smp/$smp.sort.rmdup.bam \\
METRICS_FILE=$temp/$flowcell/$lane/$smp/$flowcell\_$lane\_$smp.duplicate.xls VALIDATION_STRINGENCY=SILENT
/share/app/samtools-1.2/bin/samtools index $temp/$flowcell/$lane/$smp/$smp.sort.rmdup.bam
rm $temp/$flowcell/$lane/$smp/$smp.bam $temp/$flowcell/$lane/$smp/$smp.bf.bam $temp/$flowcell/$lane/$smp/$smp.bftmp.bam $temp/$flowcell/$lane/$smp/$smp.sort.bam

#plot
/share/Data01/lynn/projects/bin/java/jdk1.8.0_144/bin/java  -Xmx2G -Djava.io.tmpdir=/share/Data01/tianwei/tmp/java_tmp/ -XX:MaxPermSize=512m -XX:-UseGCOverheadLimit -jar /share/Data01/tianwei/Bin/TRIM_QC_4_SEQ500/qcmg/qprofiler-1.0.jar --log $temp/$flowcell/$lane/$smp/$smp.cov.chr.log --loglevel INFO --input $temp/$flowcell/$lane/$smp/$smp.sort.rmdup.bam --output $temp/$flowcell/$lane/$smp/$smp.cov.chr.xml
#perl /share/Data01/tianwei/Bin/TRIM_QC_4_SEQ500/parse_chr_data.pl -i $temp/$flowcell/$lane/$smp/$smp.cov.chr.xml > $temp/$flowcell/$lane/$smp/$smp.cov.chr.tsv
/share/Data01/tianwei/Bin/R-3.3.2/bin/Rscript $temp/$flowcell/$lane/$smp/$smp.cov.chr.R

#mapping stat
perl /share/Data01/tianwei/Bin/RNA_module/AlignmentStat/AlignmentStat_forBwa/bin/BwaMapStat.pl -bam $temp/$flowcell/$lane/$smp/$smp.sort.rmdup.bam -key $temp/$flowcell/$lane/$smp/$smp.map -samtools /share/app/samtools-1.2/bin/samtools

#insert length calculation
PATH=\$PATH:/share/app/R-3.2.1/bin/
export PATH
/share/Data01/lynn/projects/bin/java/jdk1.8.0_144/bin/java  -Xmx2G -Djava.io.tmpdir=/share/Data01/tianwei/tmp/java_tmp/ -XX:MaxPermSize=512m -XX:-UseGCOverheadLimit -jar /share/Data01/tianwei/Bin/picard/CollectInsertSizeMetrics.jar \\
I=$temp/$flowcell/$lane/$smp/$smp.sort.rmdup.bam \\
O=$temp/$flowcell/$lane/$smp/$smp.Insert.xls \\
H=$temp/$flowcell/$lane/$smp/$smp.Insert.pdf \\
M=0.5

#EstimateLibraryComplexity
/share/Data01/lynn/projects/bin/java/jdk1.8.0_144/bin/java  -Xmx2G -Djava.io.tmpdir=/share/Data01/tianwei/tmp/java_tmp/ -XX:MaxPermSize=512m -XX:-UseGCOverheadLimit -jar /share/app/picard-tools-1.137/picard.jar EstimateLibraryComplexity I=$temp/$flowcell/$lane/$smp/$smp.sort.rmdup.bam O=$temp/$flowcell/$lane/$smp/$smp.libComplexity.xls

#Copy Result
cp $temp/$flowcell/$lane/$smp/$smp.qprofile.ggplot2.pdf $out/$prefix/$lane/$flowcell"."_".$lane."_".$smp.".qprofile.ggplot2.pdf
cp $temp/$flowcell/$lane/$smp/$smp.cov.chr.xml $temp/$flowcell/$lane/$smp/$flowcell\_$lane\_$smp.dup.xls $temp/$flowcell/$lane/$smp/$smp.map*.xls $temp/$flowcell/$lane/$smp/$smp.Insert.xls $temp/$flowcell/$lane/$smp/$smp.Insert.pdf $temp/$flowcell/$lane/$smp/$smp.libComplexity.xls $out/$prefix/$lane/

echo GoodRun!! > $temp/$flowcell/$lane/$smp/$smp.sign
";
}
	close S;
	
	print QSUB "qsub $temp/$flowcell/$lane/$smp/map_$smp.sh\n";
}
close QSUB;

open QSUB,">$temp/qsub_step2.sh";
foreach my $rlID(keys %rlID_bcID){
	my @bcIDs=@{$rlID_bcID{$rlID}};
	mkpath("$out/$prefix/$rlID");
	mkpath("$temp/$rlID");
	my $merge;
	my $species;
	foreach my $bcID(@bcIDs){
		my $ID;
		($ID,$species)=split(/,/,$bcID);
		(open S,">$temp/$rlID/calculate_$rlID.sh") || die $!;

		$ID=~/(CL\d+)\_(L\d+)\_(.*)/ or $ID=~/(V\d+)\_(L\d+)\_(.*)/;
        	my ($flowcell,$lane,$smp)=($1,$2,$3);
		$merge.="$temp/$flowcell/$lane/$smp/$smp.sort.rmdup.bam ";
	}
	(open Rsc,">$temp/$rlID/$rlID.cov.chr.R") || die $!;
		print Rsc &generate_R("$temp/$rlID",$rlID);
	close Rsc;
	print S "
#!/bin/bash
#\$ -N m_$rlID
#\$ -cwd
#\$ -pe mpi 4
#\$ -l virtual_free=100M
#\$ -o $temp/$rlID/cal.o
#\$ -e $temp/$rlID/cal.e

set -e
#merging
/share/app/samtools-1.2/bin/samtools merge -f $temp/$rlID/$rlID.bam $merge
/share/app/samtools-1.2/bin/samtools index $temp/$rlID/$rlID.bam

#copy result
#mv $temp/$rlID/$rlID.bam* $out/$prefix/$rlID
";
	close S;
	print QSUB "qsub $temp/$rlID/calculate_$rlID.sh\n";
}
close QSUB;

sub get_ref
{
	my $in=shift;
	open IN,$in; my %out;
	while(<IN>){
		chomp;
		my @a=split;
		$out{$a[0]}=$a[1];
	}
	return \%out;
}

sub generate_R
{
	my $workdir=shift;
	my $prefix=shift;

my $string="
library(ggplot2)
library(stringr)
library(varhandle)
library(dplyr)
library(reshape)
library(scales)
library(lattice)
library(XML)
library(SamSeq) # for parsing SAM flags to text
library(ggpubr) # for combining PDFs

c25 <- c(\"dodgerblue2\",\"#E31A1C\", # red
         \"green4\",
         \"#6A3D9A\", # purple
         \"#FF7F00\", # orange
         \"black\",\"gold1\",
         \"skyblue2\",\"#FB9A99\", # lt pink
         \"palegreen2\",
         \"#CAB2D6\", # lt purple
         \"#FDBF6F\", # lt orange
         \"gray70\", \"khaki2\",
         \"maroon\",\"orchid1\",\"deeppink1\",\"blue1\",\"steelblue4\",
         \"darkturquoise\",\"green1\",\"yellow4\",\"yellow3\",
         \"darkorange4\",\"brown\")

setwd(\"$workdir\")

parsed_xml_file <- \"$prefix.cov.chr.xml\"
data     <- xmlParse(parsed_xml_file)

rootnode <- xmlRoot(data)
HEADER    <- rootnode[[1]][[1]] # HEADER
SEQ       <- rootnode[[1]][[2]] # SEQ
QUAL      <- rootnode[[1]][[3]] # QUAL
TAG       <- rootnode[[1]][[4]] # TAG
ISIZE     <- rootnode[[1]][[5]] # ISIZE
RNEXT     <- rootnode[[1]][[6]] # RNEXT
CIGAR     <- rootnode[[1]][[7]] # CIGAR
MAPQ      <- rootnode[[1]][[8]] # MAPQ
RNAME_POS <- rootnode[[1]][[9]] # RNAME_POS
FLAG      <- rootnode[[1]][[10]] # FLAG

SEQ_datax        <- xmlToList(SEQ)
SEQ_data         <- unlist(SEQ_datax)

num_cycles        <- max(as.numeric(SEQ_data[grep(\"attrs.value\", names(SEQ_data))]))
possible_bases    <- unlist(as.vector(str_split(SEQ_data[grep(\"BaseByCycle.CycleTally.PossibleValues..attrs.possibleValues\", names(SEQ_data))],\",\")))

SEQ_data <- SEQ_data[-grep(\"ossibleValues\",     names(SEQ_data))]
SEQ_data <- SEQ_data[-grep(\"Cycle..attrs.value\", names(SEQ_data))]
SEQ_data <- SEQ_data[-grep(\"TallyItem.percent\",  names(SEQ_data))]

count_idx         <- seq(from=1, to=length(SEQ_data), by=2)
counts            <- SEQ_data[count_idx]
countstemp        <- t(matrix(counts, nrow=length(possible_bases), ncol=num_cycles))

SEQ_df            <- data.frame(countstemp)
colnames(SEQ_df)  <- as.character(possible_bases)
SEQ_df            <- unfactor(SEQ_df)
SEQ_df\$cycle      <- 1:num_cycles

filename <- \"basemismatch_dist_per_cycle.pdf\"
dat.m <- melt(SEQ_df, id.vars = \"cycle\")
SEQ_cycle_p <- ggplot(dat.m, aes(x = cycle, y = value, fill=variable)) +
  geom_bar(stat='identity') +
  labs(title=\"Base mismatch distribution per cycle\",  y = \"number of bases\")

QUAL_datax        <- xmlToList(QUAL)
QUAL_data         <- unlist(QUAL_datax)
QUAL_data_byCycle <- QUAL_data[grep(\"QualityByCycle\", names(QUAL_data))]
QUAL_data_BadQual <- QUAL_data[grep(\"BadQualsInReads\", names(QUAL_data))]

num_cycles        <- max(as.numeric(QUAL_data[grep(\"attrs.value\", names(QUAL_data))]))
possible_quals    <- as.numeric(unlist(as.vector(str_split(QUAL_datax\$QualityByCycle\$CycleTally\$PossibleValues\$.attrs, \",\"))))

toremove          <- length(unlist(QUAL_data_byCycle[grep(\"PossibleValues\", names(QUAL_data_byCycle))])) + 1
QUAL_data_byCycle <- unlist(QUAL_data_byCycle)[toremove:length(QUAL_data_byCycle)]

quality_idx       <- seq(from=2, to=length(QUAL_data_byCycle), by=2)
count_idx         <- seq(from=1, to=length(QUAL_data_byCycle), by=2)

QUAL_data_byCycle2 <- QUAL_data_byCycle[-grep(\"Cycle..attrs.value\", names(QUAL_data_byCycle))]
QUAL_data_byCycle2 <- QUAL_data_byCycle2[-grep(\"CycleTally..attrs.possibleValues\", names(QUAL_data_byCycle2))]

count_idx         <- seq(from=1, to=length(QUAL_data_byCycle2), by=2)
counts <- QUAL_data_byCycle2[count_idx]
countstemp <- t(matrix(counts, nrow=length(possible_quals), ncol=num_cycles))

QUAL_df <- data.frame(countstemp)
colnames(QUAL_df) <- as.character(possible_quals)
QUAL_df <- unfactor(QUAL_df)
QUAL_df\$cycle <- 1:num_cycles

filename <- \"basequality_dist_per_cycle.pdf\"
dat.m <- melt(QUAL_df, id.vars = \"cycle\")
QUAL_p <- ggplot(dat.m, aes(x = cycle, y = value, fill=variable)) +
  geom_bar(stat='identity') +
  labs(title=\"Base quality distribution per cycle\",  y = \"number of bases\")

TAG_datax        <- xmlToList(TAG)
TAG_data         <- unlist(TAG_datax)

TAG_data_MismatchByCycle <- TAG_data[grep(\"MD.MismatchByCycle\", names(TAG_data))]

num_cycles        <- max(as.numeric(TAG_data[grep(\"attrs.value\", names(TAG_data))]))
possible_bases    <- unlist(as.vector(str_split(TAG_data[grep(\"MD.MismatchByCycle.CycleTally.PossibleValues..attrs.possibleValues\", names(TAG_data))],\",\")))

TAG_data_MismatchByCycle <- TAG_data_MismatchByCycle[-grep(\"ossibleValues\",     names(TAG_data_MismatchByCycle))]
TAG_data_MismatchByCycle <- TAG_data_MismatchByCycle[-grep(\"Cycle..attrs.value\", names(TAG_data_MismatchByCycle))]
TAG_data_MismatchByCycle <- TAG_data_MismatchByCycle[-grep(\"TallyItem.percent\",  names(TAG_data_MismatchByCycle))]

count_idx         <- seq(from=1, to=length(TAG_data_MismatchByCycle), by=2)
counts            <- TAG_data_MismatchByCycle[count_idx] # 400
countstemp        <- t(matrix(counts, nrow=length(possible_bases), ncol=num_cycles))

TAG_df            <- data.frame(countstemp)
colnames(TAG_df)  <- as.character(possible_bases)
TAG_df            <- unfactor(TAG_df)
TAG_df\$cycle      <- 1:num_cycles

filename <- \"basemismatch_dist_per_cycle.pdf\"
dat.m <- melt(TAG_df, id.vars = \"cycle\")
TAG_cycle_p <- ggplot(dat.m, aes(x = cycle, y = value, fill=variable)) +
  geom_bar(stat='identity') +
  labs(title=\"Base mismatch distribution per cycle\",  y = \"number of bases\")

filename <- \"basemismatch_dist_per_cycle_scaled.pdf\"
TAG_cycle_ps <- ggplot(dat.m, aes(x = cycle, y = value, fill=variable)) +
  geom_bar(position = \"fill\",stat = \"identity\") +
  scale_y_continuous(labels = percent_format()) +
  labs(title=\"Base mismatch distribution per cycle, scaled to fill 100%\",  y = \"number of bases\")

TAG_data_MutationF <- TAG_data[grep(\"MD_mutation_forward\", names(TAG_data))]

count_idx         <- seq(from=1, to=length(TAG_data_MutationF), by=3)
counts            <- TAG_data_MutationF[count_idx]
perc_idx          <- seq(from=2, to=length(TAG_data_MutationF), by=3)
percs             <- TAG_data_MutationF[perc_idx]
value_idx         <- seq(from=3, to=length(TAG_data_MutationF), by=3)
values            <- TAG_data_MutationF[value_idx]

TAG_df            <- data.frame(counts=counts,percs=percs,values=values)
TAG_df            <- unfactor(TAG_df)
TAG_df\$percs      <- as.numeric(gsub(\"%\", \"\", TAG_df\$percs))

filename <- \"basemismatch_dist_summary_forward.pdf\"
TAG_bms_p <- ggplot(TAG_df, aes(x = values, y = percs)) +
  geom_bar(stat='identity', fill = c25[1:length(values)]) +
  labs(title=\"Mismatch distribution summary (MD tag), Forward Read\",  x=\"\", y = \"% of mismatch bases\")

TAG_data_MutationR <- TAG_data[grep(\"MD_mutation_reverse\", names(TAG_data))]

count_idx         <- seq(from=1, to=length(TAG_data_MutationR), by=3)
counts            <- TAG_data_MutationR[count_idx]
perc_idx          <- seq(from=2, to=length(TAG_data_MutationR), by=3)
percs             <- TAG_data_MutationR[perc_idx]
value_idx         <- seq(from=3, to=length(TAG_data_MutationR), by=3)
values            <- TAG_data_MutationR[value_idx]

TAG_df            <- data.frame(counts=counts,
                                percs=percs,
                                values=values)
TAG_df            <- unfactor(TAG_df)
TAG_df\$percs      <- as.numeric(gsub(\"%\", \"\", TAG_df\$percs))

filename <- \"basemismatch_dist_summary_reverse.pdf\"
TAG_bmp_p <- ggplot(TAG_df, aes(x = values, y = percs)) +
  geom_bar(stat='identity', fill = c25[1:length(values)]) +
  labs(title=\"Mismatch distribution summary (MD tag), Reverse Read\",  x=\"\", y = \"% of mismatch bases\")

ISIZE_datax        <- xmlToList(ISIZE)
ISIZE_data         <- unlist(ISIZE_datax)

ISIZE_data         <- ISIZE_data[-grep(\"RG..attrs.value\", names(ISIZE_data))]

count_idx         <- seq(from=1, to=length(ISIZE_data), by=3)
start_idx         <- seq(from=3, to=length(ISIZE_data), by=3)
count             <- ISIZE_data[count_idx]
start             <- ISIZE_data[start_idx]

ISIZE_df          <- data.frame(counts=as.numeric(count),size=as.numeric(start))

ISIZE_df_lim      <- subset(ISIZE_df, size < 2500 & size > 1)
peak              <- ISIZE_df_lim\$size[which(ISIZE_df_lim\$counts == max(ISIZE_df_lim\$counts))]

filename <- \"isize_distribution.pdf\"
ISIZE_p <- ggplot(ISIZE_df, aes(x = size, y = counts)) +
  theme_bw() +
  geom_point() + geom_path() +
  scale_y_continuous(trans = \"log\") +
  labs(title=\"Insert size distribution\",  x=\"insert size (bases)\", y = \"log10(number of reads)\")

filename <- \"isize_distribution_zoom.pdf\"
ISIZE_z_p <- ggplot(ISIZE_df, aes(x = size, y = counts)) +
  theme_bw() +
  geom_point() + geom_path() +
  scale_y_log10(limits = c(1,100000000)) +
  scale_x_continuous(limits = c(1,2500)) +
  geom_vline(aes(xintercept = peak, colour = \"red\")) +
  labs(title=\"Insert size distribution, limited view\",  x=\"insert size (bases)\", y = \"log10(number of reads)\") +
  theme(legend.position=\"none\")

CIGAR_datax        <- xmlToList(CIGAR)
CIGAR_data         <- unlist(CIGAR_datax)

CIGAR_data_Fields <- CIGAR_data[grep(\"ObservedOperations.\", names(CIGAR_data))]

count_idx         <- seq(from=1, to=length(CIGAR_data_Fields), by=3)
counts            <- CIGAR_data_Fields[count_idx]
perc_idx          <- seq(from=2, to=length(CIGAR_data_Fields), by=3)
percs             <- CIGAR_data_Fields[perc_idx]
value_idx         <- seq(from=3, to=length(CIGAR_data_Fields), by=3)
values            <- CIGAR_data_Fields[value_idx]

CIGAR_df          <- data.frame(counts=counts,percs=percs,values=values)
CIGAR_df          <- unfactor(CIGAR_df)
CIGAR_df\$type     <- str_sub(CIGAR_df\$values, -1, -1)
CIGAR_df\$taglen   <- as.numeric(str_sub(CIGAR_df\$values, 1, str_length(CIGAR_df\$values)-1))
CIGAR_df\$percs    <- as.numeric(gsub(\"%\", \"\", CIGAR_df\$percs))

filename <- \"cigar_tag_distribution_rawcounts.pdf\"
CIGAR_p <- ggplot(data=CIGAR_df, aes(x=taglen, y=counts, group=type)) +
  geom_bar(stat=\"identity\") +
  facet_wrap(~type, scales = \"free\") +
  labs(title=\"CIGAR string tag distribution, by tag, raw counts\",  x=\"\", y = \"number of reads\") +
  theme(legend.position=\"none\")

filename <- \"cigar_tag_distribution_bypercent.pdf\"
CIGAR_p_p <- ggplot(data=CIGAR_df, aes(x=taglen, y=percs, group=type)) +
  geom_bar(stat=\"identity\") +
  scale_y_continuous(limits = c(0,100)) +
  facet_wrap(~type, scales = \"free\") +
  labs(title=\"CIGAR string tag distribution, by tag, percent reads\",  x=\"\", y = \"% reads\") +
  theme(legend.position=\"none\")
MAPQ_datax        <- xmlToList(MAPQ)
MAPQ_data         <- unlist(MAPQ_datax)

count_idx         <- seq(from=1, to=length(MAPQ_data), by=3)
counts            <- MAPQ_data[count_idx]
perc_idx          <- seq(from=2, to=length(MAPQ_data), by=3)
percs             <- MAPQ_data[perc_idx]
value_idx         <- seq(from=3, to=length(MAPQ_data), by=3)
values            <- MAPQ_data[value_idx]

MAPQ_df          <- data.frame(counts=counts,percs=percs,values=values)
MAPQ_df          <- unfactor(MAPQ_df)
MAPQ_df\$percs    <- as.numeric(gsub(\"%\", \"\", MAPQ_df\$percs))

filename <- \"mapq_distribution_rawcounts.pdf\"
MAPQ_rc_p <- ggplot(data=MAPQ_df, aes(x=values, y=counts)) +
  geom_bar(stat=\"identity\") +
  labs(title=\"Mapping quality distribution, raw counts\",  x=\"mapping quality\", y = \"number of reads\") +
  theme(legend.position=\"none\")

filename <- \"mapq_distribution_bypercent.pdf\"
MAPQ_p_p <- ggplot(data=MAPQ_df, aes(x=values, y=percs)) +
  geom_bar(stat=\"identity\") +
  scale_y_continuous(limits = c(0,100)) +
  labs(title=\"Mapping quality distribution, percent reads\",  x=\"mapping quality\", y = \"% reads\") +
  theme(legend.position=\"none\")
rnameposfile <- \"RNAME_POS_xml.txt\"
zz <- file(rnameposfile, open = \"wt\")
sink(zz)
sink(zz, type = \"message\")
RNAME_POS
sink(type = \"message\")
sink()

system(paste0(\"perl /share/Data01/tianwei/Bin/TRIM_QC_4_SEQ500/parse_RNAME_POS_data.pl -i \", rnameposfile))

parsed_xml_file <- paste0(rnameposfile, \".Rin\") # example: RNAME_pos_xml.txt.Rin
data <- read.csv(parsed_xml_file, stringsAsFactors = F, header=F, sep=\"\\t\")
colnames(data) <- c(\"chr\", \"start\", \"coverage\")

data <- data[which(data\$start != 0),]
data <- data[with(data, order(chr, start)), ]
data <- as.data.frame(data)

outlierlen <- 20
percmedian <- 0.70
allreads   <- sort(data\$coverage)
allreadlen <- length(allreads)-outlierlen
allreads   <- allreads[outlierlen:allreadlen] # remove the lowest N values and highest N values of all read counts
medianall  <- median(allreads) # calculate median
xmin       <- medianall - (medianall * percmedian) # set x min/max to N% of median
xmax       <- medianall + (medianall * percmedian)

filename <- \"per_chromosome_coverage_parsed_xml_file.pdf\"
RNAME_p <- ggplot(data=data, aes(x=start, y=coverage, group=chr)) +
  geom_line(aes(color=\"darkblue\")) +
  labs(title=data\$chr, x=\"\", y = \"Read Count\")+
  coord_cartesian(ylim = c(xmin, xmax)) +
  theme(strip.background = element_rect(fill = \"grey85\", colour = NA),
        legend.position=\"none\")
RNAME_p <- RNAME_p + facet_wrap(~chr, scales = \"free\")
RNAME_p <- RNAME_p + ggtitle(\"RNAME_POS: Coverage across each \@SQ\")
#print(RNAME_p)
#ggsave(filename, plot=RNAME_p, height=12, width=12)

FLAG_datax <- xmlToList(FLAG)
FLAG_data  <- unlist(FLAG_datax)[1:length(unlist(FLAG_datax))]

len        <- length(FLAG_data)

FLAG_count_idx <- seq(from=1, to=len, by=3)
FLAG_perc_idx  <- seq(from=2, to=len, by=3)
FLAG_flag_idx  <- seq(from=3, to=len, by=3)

FLAG_df    <- data.frame(count = FLAG_data[FLAG_count_idx],
                         perc  = FLAG_data[FLAG_perc_idx],
                         flag  = FLAG_data[FLAG_flag_idx]
                         )
FLAG_df\$binary <- gsub(\"(\\\\d+), \\\\w+\",\"\\\\1\", FLAG_df\$flag)
FLAG_df\$count <- unfactor(FLAG_df\$count)

for (i in 1:length(FLAG_df\$binary)) {
  tempstring         <- samFlags(strtoi(FLAG_df\$binary[i], base = 2))
  code               <- paste(names(tempstring[tempstring]), \" \", collapse=\"\")
  FLAG_df\$code[i]    <- code
  FLAG_df\$bitflag[i] <- strtoi(FLAG_df\$binary[i], base = 2)
}
  
FLAG_df <- FLAG_df[with(FLAG_df, order(-count)), ]

filename <- \"sam_flag_barplot.pdf\"
FLAG_bar_p <- ggplot(FLAG_df, aes(x = reorder(code, count), y = count)) +
  geom_bar(stat='identity') +
  coord_flip() +
  labs(title=\"SAM Flags\",  x=\"\", y = \"number of reads\")

goodAlignmentFlagVec <- c(
\"READ_PAIRED\"           =  TRUE, \"PROPER_PAIR\"             =  TRUE,
\"READ_UNMAPPED\"         = FALSE, \"MATE_UNMAPPED\"           = FALSE,
\"NOT_PRIMARY_ALIGNMENT\" = FALSE, \"READ_FAILS_VENDOR_QC\"    = FALSE,
\"DUPLICATE_READ\"        = FALSE, \"SUPPLEMENTARY_ALIGNMENT\" = FALSE
)

totalreads        <- sum(FLAG_df\$count)
goodAlign         <- 0
suppAlign         <- 0
unmapped          <- 0
dupe              <- 0

for (i in 1:dim(FLAG_df)[1]) {
  if(matchSamFlags(FLAG_df\$bitflag[i], goodAlignmentFlagVec )) {
    goodAlign = FLAG_df\$count[i] + goodAlign
  }

  if(matchSamFlags(FLAG_df\$bitflag[i], c(\"SUPPLEMENTARY_ALIGNMENT\"=TRUE))) {
    suppAlign = FLAG_df\$count[i] + suppAlign
  }

  if(matchSamFlags(FLAG_df\$bitflag[i], c(\"READ_UNMAPPED\"=TRUE)) || matchSamFlags(FLAG_df\$bitflag[i], c(\"MATE_UNMAPPED\"=TRUE))) {
    unmapped = FLAG_df\$count[i] + unmapped
  }

  if(matchSamFlags(FLAG_df\$bitflag[i], c(\"DUPLICATE_READ\"=TRUE))) {
    dupe = FLAG_df\$count[i] + dupe
  }
}

otherreads <- totalreads - goodAlign - suppAlign - unmapped - dupe

flaglabels <- c(\"Read paired in proper pair, both mapped (primary)\",
                \"Supplementary Alignment Reads\",
                \"First or second mate unmapped\",
                \"Duplicate Read\",
                \"Other (not proper pair\")

FLAG_pie_df <- data.frame(values=c(goodAlign, suppAlign, unmapped, dupe, otherreads),
                  labels=flaglabels)

FLAG_pie_p <- ggplot(FLAG_pie_df, aes(x=1, y=values, fill=labels)) +
  ggtitle(\"SAM Flag Proportions\") +
  geom_bar(stat=\"identity\") +
  guides(fill=guide_legend(override.aes=list(colour=NA))) +
  coord_polar(theta='y') +
  theme(axis.ticks=element_blank(),  # the axis ticks
        axis.title=element_blank(),  # the axis labels
        axis.text.y=element_blank(), # the 0.75, 1.00, 1.25 labels
        axis.text.x=element_text())

multi.page <- ggarrange(SEQ_cycle_p,
                        QUAL_p, TAG_cycle_p, TAG_cycle_ps, TAG_bms_p, TAG_bmp_p,
                        ISIZE_p, ISIZE_z_p,
                        CIGAR_p, CIGAR_p_p,
                        MAPQ_rc_p, MAPQ_p_p,
                        RNAME_p,
			FLAG_bar_p,
                        FLAG_pie_p,
                        nrow = 1, ncol = 1)

ggexport(multi.page, filename = \"$prefix.qprofile.ggplot2.pdf\")
";
	return $string;
}
