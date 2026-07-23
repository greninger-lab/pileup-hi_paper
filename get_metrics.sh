set -u
set -e

OUT=aln_metrics.txt

get_aln_metrics() {
  bam=$1
  out=$2

  pandepth -i $bam -t 8 -o ${bam}_pandepth &&
    zcat ${bam}_pandepth.chr.stat.gz | 
    sed '1d;$d' | cut -f 1,2,5,6 |
    while read chr len cov depth; do
      printf "%s\t%s\t%s\t%s\t%s\n" $bam $chr $len $cov $depth >> $out
    done
}

export -f get_aln_metrics

printf "File\tRef\tLength\tCoverage\tMeanDepth\n" > $OUT

{ ls DRR793869_hg38.bam SRR19895870.bam SRR36374445_hg38.bam SRR30646149_hg38.bam ERR2756169_merged.bam; } | parallel -j 3 get_aln_metrics {} $OUT
