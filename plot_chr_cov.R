library(ggplot2)

parsed_xml_file <- args[1]
output <- args[2]

data <- read.csv(parsed_xml_file, stringsAsFactors = F, header=F, sep="\t")
colnames(data) <- c("chr", "start", "coverage")

data <- data[which(data$start != 0),]

data <- data[with(data, order(chr, start)), ]
data <- as.data.frame(data)

#date     <- format(Sys.time(), "%Y%m%d-%H%M")
#textdate <- format(Sys.time(), "%Y-%m-%d %H:%M")
filename <- paste0($output, "/per_chromosome_coverage_", parsed_xml_file, ".pdf")

p <- ggplot(data=data, aes(x=start, y=coverage, group=chr)) +
  geom_line(aes(color="darkblue")) +
   labs(title=data$chr, x="", y = "Read Count")+
  coord_cartesian(ylim = c(100000, 400000)) +
  theme(strip.background = element_rect(fill = "grey85", colour = NA), 
        legend.position="none",
        plot.title = element_blank()
        ) 
p <- p + facet_wrap(~chr, scales = "free")

print(p)
ggsave(filename, plot=p, height=12, width=12)

