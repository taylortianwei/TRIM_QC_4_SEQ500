library(ggplot2)
library(stringr)
library(varhandle)
library(dplyr)
library(reshape)
library(scales)
library(lattice)
library(XML)
#install.packages("devtools")
#library(devtools)
#install_github("jefferys/SamSeq")
library(SamSeq) # for parsing SAM flags to text
library(ggpubr) # for combining PDFs

c25 <- c("dodgerblue2","#E31A1C", # red
         "green4",
         "#6A3D9A", # purple
         "#FF7F00", # orange
         "black","gold1",
         "skyblue2","#FB9A99", # lt pink
         "palegreen2",
         "#CAB2D6", # lt purple
         "#FDBF6F", # lt orange
         "gray70", "khaki2",
         "maroon","orchid1","deeppink1","blue1","steelblue4",
         "darkturquoise","green1","yellow4","yellow3",
         "darkorange4","brown")

### read the XML output file from qprofiler and generate plots for each block of data

setwd("/Users/lfink/Dropbox/BGI/data/qprofiler_plots")

parsed_xml_file <- "test.bam.qprofile.xml" # for testing only
#parsed_xml_file <- args[1] # input XML file

data     <- xmlParse(parsed_xml_file)
#xml_data <- xmlToList(data)
# Exract the root node from the xml file
rootnode <- xmlRoot(data)
# Find number of nodes in the root
#rootsize <- xmlSize(rootnode) # 1
#ns        <- xmlToDataFrame(getNodeSet(data, "//BAMReport"))

# Get the first element of the first node.
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

########### print HEADER data #########################################################
# just write header information as text, but need to do it as a ggplot so all PDFs
# can be combined into one document

# df <- data.frame()
# p <- ggplot() + annotate("text", x=0, y=100, label= "header") +
#   coord_cartesian(xlim = c(0, 100), ylim = c(0, 100)) +
#   theme(line  = element_blank(),
#         title = element_blank()) 
#    
# 
# gt <- ggplot_gtable(ggplot_build(p))
# ge <- subset(gt$layout, name == "panel")
# grid.draw(gt[ge$t:ge$b, ge$l:ge$r])

########### print HEADER data #########################################################

########### plot SEQ data #############################################################
SEQ_datax        <- xmlToList(SEQ)
SEQ_data         <- unlist(SEQ_datax)

num_cycles        <- max(as.numeric(SEQ_data[grep("attrs.value", names(SEQ_data))]))
possible_bases    <- unlist(as.vector(str_split(SEQ_data[grep("BaseByCycle.CycleTally.PossibleValues..attrs.possibleValues", names(SEQ_data))],",")))

# remove these elements
SEQ_data <- SEQ_data[-grep("ossibleValues",     names(SEQ_data))]
SEQ_data <- SEQ_data[-grep("Cycle..attrs.value", names(SEQ_data))]
SEQ_data <- SEQ_data[-grep("TallyItem.percent",  names(SEQ_data))]

count_idx         <- seq(from=1, to=length(SEQ_data), by=2)
counts            <- SEQ_data[count_idx]
countstemp        <- t(matrix(counts, nrow=length(possible_bases), ncol=num_cycles))

# and then to a data frame where the columns are basecounts and rows are cycles
SEQ_df            <- data.frame(countstemp)
colnames(SEQ_df)  <- as.character(possible_bases)
SEQ_df            <- unfactor(SEQ_df)
SEQ_df$cycle      <- 1:num_cycles

# create stacked bar plots for base distribution
filename <- "basemismatch_dist_per_cycle.pdf"
dat.m <- melt(SEQ_df, id.vars = "cycle")
SEQ_cycle_p <- ggplot(dat.m, aes(x = cycle, y = value, fill=variable)) +
  geom_bar(stat='identity') + 
  labs(title="Base mismatch distribution per cycle",  y = "number of bases")
#print(SEQ_cycle_p)
#ggsave(filename, plot=SEQ_cycle_p, height=12, width=12)
########### plot SEQ data  #############################################################

########### plot QUAL data #############################################################
QUAL_datax        <- xmlToList(QUAL)
QUAL_data         <- unlist(QUAL_datax)
QUAL_data_byCycle <- QUAL_data[grep("QualityByCycle", names(QUAL_data))]
QUAL_data_BadQual <- QUAL_data[grep("BadQualsInReads", names(QUAL_data))]

num_cycles        <- max(as.numeric(QUAL_data[grep("attrs.value", names(QUAL_data))]))
possible_quals    <- as.numeric(unlist(as.vector(str_split(QUAL_datax$QualityByCycle$CycleTally$PossibleValues$.attrs, ","))))

toremove          <- length(unlist(QUAL_data_byCycle[grep("PossibleValues", names(QUAL_data_byCycle))])) + 1
QUAL_data_byCycle <- unlist(QUAL_data_byCycle)[toremove:length(QUAL_data_byCycle)]

quality_idx       <- seq(from=2, to=length(QUAL_data_byCycle), by=2)
count_idx         <- seq(from=1, to=length(QUAL_data_byCycle), by=2)

# remove these elements
QUAL_data_byCycle2 <- QUAL_data_byCycle[-grep("Cycle..attrs.value", names(QUAL_data_byCycle))]
QUAL_data_byCycle2 <- QUAL_data_byCycle2[-grep("CycleTally..attrs.possibleValues", names(QUAL_data_byCycle2))]

# now that the elements are nice and regular, translate them to a matrix
#quality_idx       <- seq(from=2, to=length(QUAL_data_byCycle2), by=2)
count_idx         <- seq(from=1, to=length(QUAL_data_byCycle2), by=2)
#quals  <- QUAL_data_byCycle2[quality_idx]
counts <- QUAL_data_byCycle2[count_idx]
countstemp <- t(matrix(counts, nrow=length(possible_quals), ncol=num_cycles))
#qualstemp <- t(matrix(quals, nrow=35, ncol=100))

# and then to a data frame where the columns are qualities and rows are cycles
QUAL_df <- data.frame(countstemp)
colnames(QUAL_df) <- as.character(possible_quals)
#QUAL_df <- QUAL_df[1:num_cycles,1:length(possible_quals)]
QUAL_df <- unfactor(QUAL_df)
QUAL_df$cycle <- 1:num_cycles

# create stacked bar plot for base distribution
filename <- "basequality_dist_per_cycle.pdf"
dat.m <- melt(QUAL_df, id.vars = "cycle")
QUAL_p <- ggplot(dat.m, aes(x = cycle, y = value, fill=variable)) +
  geom_bar(stat='identity') + 
  labs(title="Base quality distribution per cycle",  y = "number of bases")

#print(QUAL_p)
#ggsave(filename, plot=QUAL_p, height=12, width=12)

#<BadQualsInReads>
#  <ValueTally>
#  <TallyItem count="399226957" percent="68.41%" value="0"/>
#  <TallyItem count="85988800" percent="14.74%" value="1"/>
#  <TallyItem count="37529004" percent="6.43%" value="2"/>
#  <TallyItem count="21550807" percent="3.69%" value="3"/>
#  <TallyItem count="14084945" percent="2.41%" value="4"/>
#  <TallyItem count="9868665" percent="1.69%" value="5"/>
#  <TallyItem count="7067870" percent="1.21%" value="6"/>
#  <TallyItem count="4789041" percent="0.82%" value="7"/>
#  <TallyItem count="2617242" percent="0.45%" value="8"/>
#  <TallyItem count="814182" percent="0.14%" value="9"/>
# </ValueTally>
#</BadQualsInReads>
########### plot QUAL data #############################################################

########### plot TAG data  #############################################################
# ignore CS/CQ (colorspace)
#<RG/>
#<ZM/>
#<ZP/>
#<ZF/>
#<CM/>
#<SM/>
#<IH/>
#<NH/>
#<MD> / <MismatchByCycle>
#<AllReads>
#<MD_mutation_forward> / <TallyItem count="16168986" percent="8.96%" value="A&gt;C"/> etc
#<MD_mutation_reverse> / <TallyItem count="16462970" percent="9.15%" value="A&gt;C"/>
TAG_datax        <- xmlToList(TAG)
TAG_data         <- unlist(TAG_datax)

TAG_data_MismatchByCycle <- TAG_data[grep("MD.MismatchByCycle", names(TAG_data))]

num_cycles        <- max(as.numeric(TAG_data[grep("attrs.value", names(TAG_data))]))
possible_bases    <- unlist(as.vector(str_split(TAG_data[grep("MD.MismatchByCycle.CycleTally.PossibleValues..attrs.possibleValues", names(TAG_data))],",")))

# remove these elements
TAG_data_MismatchByCycle <- TAG_data_MismatchByCycle[-grep("ossibleValues",     names(TAG_data_MismatchByCycle))]
TAG_data_MismatchByCycle <- TAG_data_MismatchByCycle[-grep("Cycle..attrs.value", names(TAG_data_MismatchByCycle))]
TAG_data_MismatchByCycle <- TAG_data_MismatchByCycle[-grep("TallyItem.percent",  names(TAG_data_MismatchByCycle))]

count_idx         <- seq(from=1, to=length(TAG_data_MismatchByCycle), by=2)
counts            <- TAG_data_MismatchByCycle[count_idx] # 400
countstemp        <- t(matrix(counts, nrow=length(possible_bases), ncol=num_cycles))

# and then to a data frame where the columns are basecounts and rows are cycles
TAG_df            <- data.frame(countstemp)
colnames(TAG_df)  <- as.character(possible_bases)
TAG_df            <- unfactor(TAG_df)
TAG_df$cycle      <- 1:num_cycles

# create stacked bar plots for base distribution
filename <- "basemismatch_dist_per_cycle.pdf"
dat.m <- melt(TAG_df, id.vars = "cycle")
TAG_cycle_p <- ggplot(dat.m, aes(x = cycle, y = value, fill=variable)) +
  geom_bar(stat='identity') + 
  labs(title="Base mismatch distribution per cycle",  y = "number of bases")

#print(TAG_cycle_p)
#ggsave(filename, plot=TAG_cycle_p, height=12, width=12)

filename <- "basemismatch_dist_per_cycle_scaled.pdf"
TAG_cycle_ps <- ggplot(dat.m, aes(x = cycle, y = value, fill=variable)) + 
  geom_bar(position = "fill",stat = "identity") +
  scale_y_continuous(labels = percent_format()) +
  labs(title="Base mismatch distribution per cycle, scaled to fill 100%",  y = "number of bases")
#print(TAG_cycle_ps)
#ggsave(filename, plot=TAG_cycle_ps, height=12, width=12)
###### MD_mutation_forward/reverse
# <MD_mutation_forward>
#   <ValueTally>
#   <TallyItem count="16168986" percent="8.96%" value="A&gt;C"/>
#   <TallyItem count="32753380" percent="18.14%" value="A&gt;G"/>
  
## FORWARD READ SUMMARY
TAG_data_MutationF <- TAG_data[grep("MD_mutation_forward", names(TAG_data))]

count_idx         <- seq(from=1, to=length(TAG_data_MutationF), by=3)
counts            <- TAG_data_MutationF[count_idx] 
perc_idx          <- seq(from=2, to=length(TAG_data_MutationF), by=3)
percs             <- TAG_data_MutationF[perc_idx] 
value_idx         <- seq(from=3, to=length(TAG_data_MutationF), by=3)
values            <- TAG_data_MutationF[value_idx] 

# and then to a data frame where the columns are basecounts and rows are cycles
TAG_df            <- data.frame(counts=counts,percs=percs,values=values)
TAG_df            <- unfactor(TAG_df)
TAG_df$percs      <- as.numeric(gsub("%", "", TAG_df$percs))

# create stacked bar plots for base distribution
filename <- "basemismatch_dist_summary_forward.pdf"
TAG_bms_p <- ggplot(TAG_df, aes(x = values, y = percs)) +
  geom_bar(stat='identity', fill = c25[1:length(values)]) + 
  labs(title="Mismatch distribution summary (MD tag), Forward Read",  x="", y = "% of mismatch bases")
#print(TAG_bms_p)
#ggsave(filename, plot=TAG_bms_p, height=12, width=12)

## REVERSE READ SUMMARY
TAG_data_MutationR <- TAG_data[grep("MD_mutation_reverse", names(TAG_data))]

count_idx         <- seq(from=1, to=length(TAG_data_MutationR), by=3)
counts            <- TAG_data_MutationR[count_idx] 
perc_idx          <- seq(from=2, to=length(TAG_data_MutationR), by=3)
percs             <- TAG_data_MutationR[perc_idx] 
value_idx         <- seq(from=3, to=length(TAG_data_MutationR), by=3)
values            <- TAG_data_MutationR[value_idx] 

# and then to a data frame where the columns are basecounts and rows are cycles
TAG_df            <- data.frame(counts=counts,
                                percs=percs,
                                values=values)
TAG_df            <- unfactor(TAG_df)
TAG_df$percs      <- as.numeric(gsub("%", "", TAG_df$percs))
filename <- "basemismatch_dist_summary_reverse.pdf"
TAG_bmp_p <- ggplot(TAG_df, aes(x = values, y = percs)) +
  geom_bar(stat='identity', fill = c25[1:length(values)]) + 
  labs(title="Mismatch distribution summary (MD tag), Reverse Read",  x="", y = "% of mismatch bases")
print(TAG_bmp_p)
ggsave(filename, plot=TAG_bmp_p, height=12, width=12)
########### plot TAG data  #############################################################

########### plot ISIZE data  #############################################################
#<ISIZE>
#  <RG value="EMPTY">
#  <RangeTally>
#  <RangeTallyItem count="11967846" end="0" start="0"/>
#  <RangeTallyItem count="14992" end="2" start="2"/>
ISIZE_datax        <- xmlToList(ISIZE)
ISIZE_data         <- unlist(ISIZE_datax)

# remove this element
ISIZE_data         <- ISIZE_data[-grep("RG..attrs.value", names(ISIZE_data))]

count_idx         <- seq(from=1, to=length(ISIZE_data), by=3)
start_idx         <- seq(from=3, to=length(ISIZE_data), by=3)
count             <- ISIZE_data[count_idx] 
start             <- ISIZE_data[start_idx] 

ISIZE_df          <- data.frame(counts=as.numeric(count),size=as.numeric(start))

ISIZE_df_lim      <- subset(ISIZE_df, size < 2500 & size > 1)
peak              <- ISIZE_df_lim$size[which(ISIZE_df_lim$counts == max(ISIZE_df_lim$counts))]

# create log scale line plot
filename <- "isize_distribution.pdf"
ISIZE_p <- ggplot(ISIZE_df, aes(x = size, y = counts)) +
  theme_bw() +
  geom_point() + geom_path() + 
  #coord_cartesian(xlim=c(0, 5000), ylim=c(0, 5000)) +
  scale_y_continuous(trans = "log") + 
  labs(title="Insert size distribution",  x="insert size (bases)", y = "log10(number of reads)")
#print(ISIZE_p)
#ggsave(filename, plot=ISIZE_p, height=12, width=12)

filename <- "isize_distribution_zoom.pdf"
ISIZE_z_p <- ggplot(ISIZE_df, aes(x = size, y = counts)) +
  theme_bw() +
  geom_point() + geom_path() + 
  scale_y_log10(limits = c(1,100000000)) + 
  scale_x_continuous(limits = c(1,2500)) + 
  geom_vline(aes(xintercept = peak, colour = "red")) +
  labs(title="Insert size distribution, limited view",  x="insert size (bases)", y = "log10(number of reads)") +
  theme(legend.position="none")
#print(ISIZE_z_p)
#ggsave(filename, plot=ISIZE_z_p, height=12, width=12)
########### plot ISIZE data  #############################################################

########### plot CIGAR data  #############################################################
# <CIGAR>
#   <ObservedOperations>
#   <ValueTally>
#   <TallyItem count="4409845" percent="10.68%" value="1D"/>
#   <TallyItem count="1272592" percent="3.08%" value="2D"/>
#   ..
# <TallyItem count="4818" percent="0.01%" value="1H"/>
#   <TallyItem count="22021" percent="0.05%" value="2H"/>
#   ..
CIGAR_datax        <- xmlToList(CIGAR)
CIGAR_data         <- unlist(CIGAR_datax)

CIGAR_data_Fields <- CIGAR_data[grep("ObservedOperations.", names(CIGAR_data))]

count_idx         <- seq(from=1, to=length(CIGAR_data_Fields), by=3)
counts            <- CIGAR_data_Fields[count_idx] 
perc_idx          <- seq(from=2, to=length(CIGAR_data_Fields), by=3)
percs             <- CIGAR_data_Fields[perc_idx] 
value_idx         <- seq(from=3, to=length(CIGAR_data_Fields), by=3)
values            <- CIGAR_data_Fields[value_idx] 

CIGAR_df          <- data.frame(counts=counts,percs=percs,values=values)
CIGAR_df          <- unfactor(CIGAR_df)
CIGAR_df$type     <- str_sub(CIGAR_df$values, -1, -1)
CIGAR_df$taglen   <- as.numeric(str_sub(CIGAR_df$values, 1, str_length(CIGAR_df$values)-1))
CIGAR_df$percs    <- as.numeric(gsub("%", "", CIGAR_df$percs))

# plot bar plots for each tag type (deletion, insertion, etc)
filename <- "cigar_tag_distribution_rawcounts.pdf"
CIGAR_p <- ggplot(data=CIGAR_df, aes(x=taglen, y=counts, group=type)) +
  geom_bar(stat="identity") +
  facet_wrap(~type, scales = "free") +
  labs(title="CIGAR string tag distribution, by tag, raw counts",  x="", y = "number of reads") +
  theme(legend.position="none") 
#print(CIGAR_p)
#ggsave(filename, plot=CIGAR_p, height=12, width=12)

filename <- "cigar_tag_distribution_bypercent.pdf"
CIGAR_p_p <- ggplot(data=CIGAR_df, aes(x=taglen, y=percs, group=type)) +
  geom_bar(stat="identity") +
  scale_y_continuous(limits = c(0,100)) +
  facet_wrap(~type, scales = "free") +
  labs(title="CIGAR string tag distribution, by tag, percent reads",  x="", y = "% reads") +
  theme(legend.position="none") 
#print(CIGAR_p_p)
#ggsave(filename, plot=CIGAR_p_p, height=12, width=12)

# M	alignment match (can be a sequence match or mismatch) 
# I	insertion to the reference
# D	deletion from the reference
# N	skipped region from the reference 
# S	soft clipping (clipped sequences present in SEQ)
# H	hard clipping (clipped sequences NOT present in SEQ) 
# P	padding (silent deletion from padded reference) 
# =	sequence match
# X	sequence mismatch 
########### plot CIGAR data  #############################################################

########### plot MAPQ data  #############################################################
# <MAPQ>
#   <ValueTally>
#   <TallyItem count="23588474" percent="4.04%" value="0"/>
#   <TallyItem count="738853" percent="0.13%" value="1"/>
#   <TallyItem count="468136" percent="0.08%" value="2"/>
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
MAPQ_df$percs    <- as.numeric(gsub("%", "", MAPQ_df$percs))

filename <- "mapq_distribution_rawcounts.pdf"
MAPQ_rc_p <- ggplot(data=MAPQ_df, aes(x=values, y=counts)) +
  geom_bar(stat="identity") +
  labs(title="Mapping quality distribution, raw counts",  x="mapping quality", y = "number of reads") +
  theme(legend.position="none") 
#print(MAPQ_rc_p)
#ggsave(filename, plot=MAPQ_rc_p, height=12, width=12)

filename <- "mapq_distribution_bypercent.pdf"
MAPQ_p_p <- ggplot(data=MAPQ_df, aes(x=values, y=percs)) +
  geom_bar(stat="identity") +
  scale_y_continuous(limits = c(0,100)) +
  labs(title="Mapping quality distribution, percent reads",  x="mapping quality", y = "% reads") +
  theme(legend.position="none") 
#print(MAPQ_p_p)
#ggsave(filename, plot=MAPQ_p_p, height=12, width=12)
########### plot MAPQ data  #############################################################

########### plot RNAME_POS data  #############################################################
#RNAME_POS_datax        <- xmlToList(RNAME_POS)
#RNAME_POS_data         <- unlist(RNAME_POS_datax)

# write stripped RNAME_POS XML to a text file so we can run a Perl script on it
rnameposfile <- "RNAME_POS_xml.txt"
zz <- file(rnameposfile, open = "wt")
sink(zz)
sink(zz, type = "message")
RNAME_POS
sink(type = "message")
sink()

# run Perl script
system(paste0("./parse_RNAME_POS_data.pl -i ", rnameposfile))

# proceed with Perl-parsed data
parsed_xml_file <- paste0(rnameposfile, ".Rin") # example: RNAME_pos_xml.txt.Rin
data <- read.csv(parsed_xml_file, stringsAsFactors = F, header=F, sep="\t")
colnames(data) <- c("chr", "start", "coverage")

data <- data[which(data$start != 0),]
data <- data[with(data, order(chr, start)), ]
data <- as.data.frame(data)

# find sort of average read count value to set axes rationally
outlierlen <- 20
percmedian <- 0.70
allreads   <- sort(data$coverage)
allreadlen <- length(allreads)-outlierlen
allreads   <- allreads[outlierlen:allreadlen] # remove the lowest N values and highest N values of all read counts
medianall  <- median(allreads) # calculate median
xmin       <- medianall - (medianall * percmedian) # set x min/max to N% of median
xmax       <- medianall + (medianall * percmedian)

#date     <- format(Sys.time(), "%Y%m%d-%H%M")
#textdate <- format(Sys.time(), "%Y-%m-%d %H:%M")
filename <- paste0("per_chromosome_coverage_", parsed_xml_file, ".pdf")
RNAME_p <- ggplot(data=data, aes(x=start, y=coverage, group=chr)) +
  geom_line(aes(color="darkblue")) +
  labs(title=data$chr, x="", y = "Read Count")+
  coord_cartesian(ylim = c(xmin, xmax)) +
  theme(strip.background = element_rect(fill = "grey85", colour = NA), 
        legend.position="none")
RNAME_p <- RNAME_p + facet_wrap(~chr, scales = "free") 
RNAME_p <- RNAME_p + ggtitle("RNAME_POS: Coverage across each @SQ")
print(RNAME_p)
ggsave(filename, plot=RNAME_p, height=12, width=12)
########### plot RNAME_POS data  #############################################################

########### plot FLAG data  #############################################################
# read paired (0x1) 1 
# read mapped in proper pair (0x2) 2
# read unmapped (0x4) 4 
# mate unmapped (0x8) 8 
# read reverse strand (0x10) 16 
# mate reverse strand (0x20) 32 
# first in pair (0x40) 64 
# second in pair (0x80) 128 
# not primary alignment (0x100) 256 
# read fails platform/vendor quality checks (0x200) 512
# read is PCR or optical duplicate (0x400) 1024
# supplementary alignment (0x800) 2048

FLAG_datax <- xmlToList(FLAG)
# remove unnecessary first 5 elements
FLAG_data  <- unlist(FLAG_datax)[1:length(unlist(FLAG_datax))]

len        <- length(FLAG_data)

FLAG_count_idx <- seq(from=1, to=len, by=3)
FLAG_perc_idx  <- seq(from=2, to=len, by=3)
FLAG_flag_idx  <- seq(from=3, to=len, by=3)

FLAG_df    <- data.frame(count = FLAG_data[FLAG_count_idx],
                         perc  = FLAG_data[FLAG_perc_idx],
                         flag  = FLAG_data[FLAG_flag_idx]
                         )
FLAG_df$binary <- gsub("(\\d+), \\w+","\\1", FLAG_df$flag)
FLAG_df$count <- unfactor(FLAG_df$count)

for (i in 1:length(FLAG_df$binary)) {
  tempstring         <- samFlags(strtoi(FLAG_df$binary[i], base = 2))
  code               <- paste(names(tempstring[tempstring]), " ", collapse="")
  #print(code)
  FLAG_df$code[i]    <- code
  FLAG_df$bitflag[i] <- strtoi(FLAG_df$binary[i], base = 2)
}

#barplot(FLAG_df$count, xlab=FLAG_df$code, las=1)
FLAG_df <- FLAG_df[with(FLAG_df, order(-count)), ]

# plot read counts for all flags
filename <- "sam_flag_barplot.pdf"
FLAG_bar_p <- ggplot(FLAG_df, aes(x = reorder(code, count), y = count)) +
  geom_bar(stat='identity') + 
  coord_flip() +
  labs(title="SAM Flags",  x="", y = "number of reads")
#print(FLAG_bar_p)
#ggsave(filename, plot=FLAG_bar_p, height=12, width=12)

############## plot proportions of mapped and unmapped reads
goodAlignmentFlagVec <- c(
"READ_PAIRED"           =  TRUE, "PROPER_PAIR"             =  TRUE,
"READ_UNMAPPED"         = FALSE, "MATE_UNMAPPED"           = FALSE,
"NOT_PRIMARY_ALIGNMENT" = FALSE, "READ_FAILS_VENDOR_QC"    = FALSE,
"DUPLICATE_READ"        = FALSE, "SUPPLEMENTARY_ALIGNMENT" = FALSE
)

totalreads        <- sum(FLAG_df$count)
goodAlign         <- 0
suppAlign         <- 0
unmapped          <- 0
dupe              <- 0

for (i in 1:dim(FLAG_df)[1]) {
  if(matchSamFlags(FLAG_df$bitflag[i], goodAlignmentFlagVec )) {
    goodAlign = FLAG_df$count[i] + goodAlign
  }

  if(matchSamFlags(FLAG_df$bitflag[i], c("SUPPLEMENTARY_ALIGNMENT"=TRUE))) {
    suppAlign = FLAG_df$count[i] + suppAlign
  }

  if(matchSamFlags(FLAG_df$bitflag[i], c("READ_UNMAPPED"=TRUE)) || matchSamFlags(FLAG_df$bitflag[i], c("MATE_UNMAPPED"=TRUE))) {
    unmapped = FLAG_df$count[i] + unmapped
  }
  
  if(matchSamFlags(FLAG_df$bitflag[i], c("DUPLICATE_READ"=TRUE))) {
    dupe = FLAG_df$count[i] + dupe
  }
}

otherreads <- totalreads - goodAlign - suppAlign - unmapped - dupe

flaglabels <- c("Read paired in proper pair, both mapped (primary)",
                "Supplementary Alignment Reads",
                "First or second mate unmapped",
                "Duplicate Read",
                "Other (not proper pair")

FLAG_pie_df <- data.frame(values=c(goodAlign, suppAlign, unmapped, dupe, otherreads),
                  labels=flaglabels)

FLAG_pie_p <- ggplot(FLAG_pie_df, aes(x=1, y=values, fill=labels)) +
  ggtitle("SAM Flag Proportions") +
  geom_bar(stat="identity") +
  # remove black diagonal line from legend
  guides(fill=guide_legend(override.aes=list(colour=NA))) +
  # polar coordinates
  coord_polar(theta='y') +
  # label aesthetics
  theme(axis.ticks=element_blank(),  # the axis ticks
        axis.title=element_blank(),  # the axis labels
        axis.text.y=element_blank(), # the 0.75, 1.00, 1.25 labels
        axis.text.x=element_text())
#print(FLAG_pie_p)
#ggsave(filename, plot=FLAG_pie_p, height=12, width=12)
########### plot FLAG data  #############################################################

########### COMBINE ALL PLOTS INTO ONE PDF
multi.page <- ggarrange(SEQ_cycle_p, 
                        QUAL_p, TAG_cycle_p, TAG_cycle_ps, TAG_bms_p, TAG_bmp_p,
                        ISIZE_p, ISIZE_z_p,
                        CIGAR_p, CIGAR_p_p,
                        MAPQ_rc_p, MAPQ_p_p,
                        RNAME_p,
                        FLAG_pie_p,
                        # add FLAG plots...
                        nrow = 1, ncol = 1)

#multi.page[[1]] # Visualize page 1
#multi.page[[2]] # Visualize page 2

#You can also export the arranged plots to a pdf file using the function ggexport() [ggpubr]:
ggexport(multi.page, filename = "multi.page.ggplot2.pdf")

