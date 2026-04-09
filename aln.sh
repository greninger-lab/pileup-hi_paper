minimap2 -ax sr Grif_1614_genome.fa -t 20 \
  SRR19895870_0.fq.gz SRR19895870_1.fq.gz |
  samtools view -@ 2 -F 2052 -h -b > SRR19895870_unsorted 

samtools sort -@ 10 -o SRR19895870.bam SRR19895870_unsorted && 
  rm SRR19895870_unsorted

minimap2 -t 20 -ax sr --secondary no ../REF_GENOMES/hg38.fa \
  DRR793869_0.fq.gz DRR793869_1.fq.gz |
  samtools view -bS -F 2052 -h > DRR793869_hg38

samtools sort -@ 20 -o DRR793869_hg38.bam DRR793869_hg38 &&
  samtools index -@ 20 DRR793869_hg38.bam &&
  rm DRR793869_hg38

minimap2 -t 20 -ax map-pb --secondary no ../REF_GENOMES/hg38.fa SRR36374445_0.fq.gz |
  samtools view -bS -F 2052 -h > SRR63734445_hg38

samtools sort -@ 10 -o SRR36374445_hg38.bam SRR36374445_hg38 &&
  samtools index -@ 10 SRR36374445_hg38.bam &&
  rm SRR36374445_hg38

minimap2 -t 20 -ax map-pb --secondary no ../REF_GENOMES/hg38.fa \
  output/SRR30646149_0.fq.gz |
  samtools view -bS -F 2052 -h > SRR30646149_hg38

samtools sort -@ 10 -o SRR30646149_hg38.bam SRR30646149_hg38 &&
  samtools index -@ 10 SRR30646149_hg38.bam &&
  rm SRR30646149_hg38

## T. pallidum
samtools merge --threads 1 ERR2756166_merged.bam 1/ERR2756166_genomic_sorted.bam 2/ERR2756166_rRNA_sorted.bam 3/ERR2756166_tRNA_sorted.bam
