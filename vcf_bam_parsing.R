library(GenomicRanges)
library(GenomicAlignments)
library(Rsamtools)
library(VariantAnnotation)
library(stringr)
library(ShortRead)
library(varhandle) #unfactor()
library(data.table) #data.table()

vcfs <- c(
  "test.vcf"
)

bams <- c(
  "test.bam"
)

bamfiles <- as.matrix(bams, ncol=20)

vcfpath  <- "/path/to/vcf/"
vcffiles <- as.matrix(vcfs, ncol=20)
vcffiles <- paste0(vcfpath, vcffiles)

x       <- 1
bam     <- bamfiles[x]
vcffile <- vcffiles[x]

vcf      <- readVcf(vcffile, "hs37d5")

rowstokeep <- vector()
logdf    <- data.frame(variant_num=numeric(length(vcf)),
                       sq=character(length(vcf)),
                       start=numeric(length(vcf)),
                       ref=character(length(vcf)),
                       alt=character(length(vcf)),
                       filter=character(length(vcf)),
                       num_reads=numeric(length(vcf)),
                       num_novel_starts=numeric(length(vcf)),
                       num_alt_novel_starts=numeric(length(vcf)),
                       not_altref=numeric(length(vcf)),
                       num_indels=numeric(length(vcf))
)
logdf <- unfactor(logdf)


for (i in 1:length(vcf)) {
  #for (i in 1:10) {
  # loop over each SNV; here is the first one
  snvgr    <- rowRanges(vcf[i,])
  
  snvstart <- start(vcf[i,])
  width    <- width(vcf[i,])
  ref      <- as.data.frame((rowRanges(vcf[i,])))$REF
  alt      <- as.character(as.data.frame((rowRanges(vcf[i,])))$ALT[[1]])
  filter   <- as.character(as.data.frame((rowRanges(vcf[i,])))$FILTER[[1]])
  seqname  <- as.character(as.data.frame((rowRanges(vcf[i,])))$seqnames[[1]])
  
  print(paste0("VCF: ", vcffile, " Variant: ", i))
  
  logdf$variant_num[i] <- i
  logdf$sq[i]          <- seqname
  logdf$start[i]       <- snvstart
  logdf$filter[i]      <- filter
  logdf$ref[i]         <- ref
  logdf$alt[i]         <- alt
  
  
  
  # skip variants that do not pass filter (PASS)
  if(filter != 'PASS') {
    #print(paste("SKIPPING (not PASS filter):", logdf[i,]), sep="\t")
    #print(paste("SKIPPING variant", i, ", does not pass filter:", filter))
    next
  }
  
  # skip non-SNVs
  if(width != 1) {
    # create log file data
    temp <- subset(as.data.frame(snvgr), select=c(seqnames, start, end))
    temp$num_reads <- NA
    temp$num_novel_starts <- NA
    #logdf <- rbind.data.frame(logdf, temp)
    
    #print(paste("SKIPPING:", temp$seqnames, temp$start, temp$end, num_reads, num_novel_starts), sep="\t")
    #print(paste("SKIPPING variant", i, ", not a SNV"))
    
    # don't try to filter it, but keep it in the VCF for later use
    rowstokeep <- c(rowstokeep, i)
    next
  }
  
  # set up filter for reads
  # use MAPQ threshold of 20 (http://gatkforums.broadinstitute.org/gatk/discussion/4260/phred-scaled-quality-scores)
  #    For many purposes, a Phred Score of 20 or above is acceptable, because this means that 
  #    whatever it qualifies is 99% accurate, with a 1% chance of error.
  # flag=(isSecondaryAlignment=FALSE)
  p1 <- ScanBamParam(which=snvgr, 
                     what=scanBamWhat(), # all fields
                     mapqFilter=20,
                     flag=scanBamFlag( 
                       isUnmappedQuery = FALSE, 
                       isDuplicate = FALSE, 
                       isNotPassingQualityControls = FALSE
                     )
  )
  
  # read BAM and filter out only the good reads that map to the desired SNV
  # count the novel start positions; should be at least 5
  res1             <- scanBam(bam, param=p1)
  start_positions  <- res1[[1]]$pos # start positions               for each read
  strands          <- as.character(res1[[1]]$strand)
  sequences        <- as.character(res1[[1]]$seq)  # sequences      for each read
  basequals        <- as.character(res1[[1]]$qual) # base qualities for each read
  cigars           <- as.character(res1[[1]]$cigar)
  #flags            <- as.character(res1[[1]]$flag)
  
  num_reads        <- dim(as.matrix(start_positions))[1]
  novel_starts     <- unique(as.matrix(start_positions))
  num_novel_starts <- dim(novel_starts)[1]
  
  logdf$num_reads[i]            <- num_reads
  logdf$num_novel_starts[i]     <- num_novel_starts
  
  # check to see if all reads with same start have same sequence; get all reads covering this SNV, and find the actua
  #  base at the SNV position; then keep reads that are unique based on start position AND SNV base
  seqsperpos            <- data.frame(seq=sequences, pos=as.matrix(start_positions), strand=strands, quals=basequals, cigar=cigars)
  seqsperpos            <- unfactor(seqsperpos)
  seqsperpos$snv_index  <- snvstart - seqsperpos$pos + 1
  seqsperpos$base       <- substr(seqsperpos$seq,   seqsperpos$snv_index, seqsperpos$snv_index)
  seqsperpos$qual       <- substr(seqsperpos$quals, seqsperpos$snv_index, seqsperpos$snv_index)
  # unique reads (based on start pos and base):
  seqsperpos$new_var    <- paste(seqsperpos$pos, seqsperpos$base ,sep = "_")
  seqsperpos_uniq       <- seqsperpos[!duplicated(seqsperpos$new_var),]
  uniqreadinfo          <- seqsperpos_uniq
  
  ## make data frame with read start position and sequence string for unique start sites only
  #readinfo         <- data.frame(pos=as.matrix(start_positions), sequence=sequences, quals=basequals, cigar=cigars)
  #uniqreadinfo     <- subset(readinfo, !duplicated(pos))
  
  ## create log file data
  #temp <- subset(as.data.frame(snvgr), select=c(seqnames, start, end))
  #print(paste("VARIANT", i, ":", temp$seqnames, temp$start, temp$end, num_reads, num_novel_starts), sep="\t")
  
  # keep track of how many ALT alleles with novel start are found
  is_alt     <- 0
  not_altref <- 0 # base in read is neither ref nor alt (?)
  num_indels <- 0 # count how many reads are skipped because they contain an insertion or deletion
  bases <- vector()
  quals <- vector()
  #print(basequals)
  for (j in 1:dim(uniqreadinfo)[1]) {
    #print(paste("READINDEX:", j, uniqreadinfo$cigar[j]))
    if(length(grep("D", uniqreadinfo$cigar[j], value=TRUE)) >= 1 || length(grep("I", uniqreadinfo$cigar[j], value=TRUE)) >= 1) {
      #print(paste("SKIPPING", uniqreadinfo$cigar[j]))
      num_indels <- num_indels + 1
      next
    }
    
    #baseindex <- snvstart - uniqreadinfo$pos[j] + 1
    #readbase  <- unlist(str_split(uniqreadinfo$sequence[j], ""))[baseindex]
    #readbasq  <- unlist(str_split(uniqreadinfo$quals[j],    ""))[baseindex]
    ##print(paste(readbase, readbasq))
    #basequal  <- phred2ASCIIOffset(readbasq)
    #bases     <- c(bases, readbase)
    #quals     <- c(quals, basequal)
    
    basequal  <- phred2ASCIIOffset(uniqreadinfo$qual[j])
    bases     <- c(bases, uniqreadinfo$base[j])
    quals     <- c(quals, basequal)
    
    #print(paste(readbase, basequal))
    if(uniqreadinfo$base[j] == ref & uniqreadinfo$qual[j] >= 10) {
      #print(paste0("Base (", uniqreadinfo$base[j], ") is reference (", ref, ")"))
    }
    else if(uniqreadinfo$base[j] == alt & uniqreadinfo$qual[j] >= 10) {
      #print(paste0("Base (", uniqreadinfo$base[j], ") is alt       (", alt, ")"))
      is_alt <- is_alt + 1
    }
    else if(uniqreadinfo$base[j] != alt & uniqreadinfo$qual[j] >= 10) {
      #print(paste0("Base (", uniqreadinfo$base[j], ") is not ref or alt (!!!)"))
      not_altref <- not_altref + 1
    }
  }
  #print(paste(bases), sep=",")
  #print(paste(quals), sep=",")
  #print(paste("NOVEL ALTs:", is_alt))
  #print(paste("INDEL READS SKIPPED:", num_indels))
  #print("_______")
  
  logdf$num_alt_novel_starts[i] <- is_alt
  logdf$not_altref[i]           <- not_altref
  logdf$num_indels[i]           <- num_indels
  
  # if fewer than 4 or 5 novel starts, remove variant
  #if(is_alt >= 4) {
    rowstokeep <- c(rowstokeep, i)
  #}
}

vcf <- vcf[rowstokeep,]
newvcfname <- paste(basename(vcffile), "_anynovelstarts.vcf", sep="")
newvcfname <- str_replace(newvcfname, ".vcf", "")
writeVcf(vcf, newvcfname)

# write log file
logfilename <- paste(basename(vcffile), "_", format(Sys.time(), "%Y%m%d%X"), "_novelstarts.log", sep="")
logfilename <- str_replace_all(logfilename, ":", "")
write.table(logdf, logfilename, quote=FALSE, sep="\t", col.names=TRUE, row.names=FALSE)

print(paste0(bam, " FILTERING COMPLETE!!! -----------------------------------------------------"))
