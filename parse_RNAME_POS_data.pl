#!/usr/bin/perl

use strict;
use Data::Dumper;
use Getopt::Long;

my $file    = "";   # qprofiler output XML file

&GetOptions(
    "i=s"   => \$file
);

if(! defined $file) {
    die print STDERR "Please specify an input file with -i\n";
}

my $found   = 1;
my $outfile = $file.".Rin";

local($/)   = undef;
open(FH, $file) || die;
my $fc  = <FH>;
close(FH);

my @rname       = ($fc =~ /<RNAME\_POS>(.+)<\/RNAME\_POS>/sg);
my @rnames      = ($rname[0] =~ /(<RNAME.+?)<\/RNAME>/sg);

#print Dumper @rnames;

my %chr_details = ();

open(FH, ">".$outfile) || die;
foreach (@rnames) {
    my $xml = $_;
    #print STDERR "XML: $xml\n";
    if($xml =~ /value=\"\*\"/) {
        #print STDERR "Skipping *\n";
        next;
    }

    $xml    =~ /maxPosition="(\d+)" minPosition="(\d+)" value="(\w+)"/;
    my $min = $2;
    my $max = $1;
    my $chr = $3;
    #print "$chr: $min - $max\n";

    $chr_details{$chr}  = join "\t", $min, $max;

    #my @lines  = ($xml =~ /(<RangeTallyItem.+?\/>)/sg);
    #print Dumper @lines;

    my @cov = ($xml =~ /count="(\d+)" end="\d+" start="(\d+)"/sg);
    #print Dumper @cov;

    for (my $i=0;$i<=$#cov;$i+=2) {
        # chr, start range, coverage count
        print FH join "\t", $chr, $cov[$i+1], $cov[$i];
        print FH "\n";
    }
}
close(FH);
exit(0);

=cut
<RNAME count="1840861" maxPosition="59033784" minPosition="2649614" value="chrY">
<RangeTally>
<RangeTallyItem count="2057" end="2999999" start="2000000"/>
<RangeTallyItem count="17512" end="3999999" start="3000000"/>
<RangeTallyItem count="13060" end="4999999" start="4000000"/>
<RangeTallyItem count="13584" end="5999999" start="5000000"/>
<RangeTallyItem count="4363" end="6999999" start="6000000"/>
<RangeTallyItem count="3240" end="7999999" start="7000000"/>
<RangeTallyItem count="500" end="8999999" start="8000000"/>
<RangeTallyItem count="90217" end="9999999" start="9000000"/>
<RangeTallyItem count="153640" end="10999999" start="10000000"/>
<RangeTallyItem count="1256852" end="13999999" start="13000000"/>
<RangeTallyItem count="1080" end="14999999" start="14000000"/>
<RangeTallyItem count="2150" end="15999999" start="15000000"/>
<RangeTallyItem count="3323" end="16999999" start="16000000"/>
<RangeTallyItem count="1081" end="17999999" start="17000000"/>
<RangeTallyItem count="737" end="18999999" start="18000000"/>
<RangeTallyItem count="4118" end="19999999" start="19000000"/>
<RangeTallyItem count="2727" end="20999999" start="20000000"/>
<RangeTallyItem count="1491" end="21999999" start="21000000"/>
<RangeTallyItem count="932" end="22999999" start="22000000"/>
<RangeTallyItem count="568" end="23999999" start="23000000"/>
<RangeTallyItem count="481" end="24999999" start="24000000"/>
<RangeTallyItem count="739" end="25999999" start="25000000"/>
<RangeTallyItem count="1524" end="26999999" start="26000000"/>
<RangeTallyItem count="1453" end="27999999" start="27000000"/>
<RangeTallyItem count="43259" end="28999999" start="28000000"/>
<RangeTallyItem count="2" end="32999999" start="32000000"/>
<RangeTallyItem count="159209" end="58999999" start="58000000"/>
<RangeTallyItem count="60962" end="59999999" start="59000000"/>
</RangeTally>
