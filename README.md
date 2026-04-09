# pileup-hi paper analysis
This repository contains code for the publication: "*pileup-hi: an ultra-high throughput, customizable pileup program for large datasets*"

## Prelude

- pileup-hi version 0.9.2 was used for all analysis. You can download it using Cargo:
- All testing was performed on MacOS Sequoia 15.7.4
- this analysis requires 1.5TB+ of disk space.

```bash
cargo install pileup-hi --version 0.9.2
```


## Other software used
- samtools 1.2.3
- htslib 1.2.3
- perbase 1.2.0
- b3sum 1.8.3
- minimap2 v2.30-r1290-dirty
- python 3.14.2
- R and Rstudio (along with packages specified in .Rmd files)

**NOTE:** for the instructions below, it is assumed that you have all the software listed somewhere in `$PATH`. For information on how to move software to `$PATH`, see [this thread](https://unix.stackexchange.com/questions/183295/adding-programs-to-path). 

## Overall description - generating data

Analysis consisted of running different pileup programs on five datasets. This was done 3 python scripts that can be adjusted to run a selection of tools on a selection of datasets. By default: they are configured to generate data for the entire paper.

These scripts are described in detail below:

### bench.py: run time and peak memory usage 

This script launches tools on specified input files and records performance information to a spreadsheet `./reports/`.

The script is configured by default to run all conditions on all files in triplicate, but you can modify this by changing the following variables: 

change iterations:
```python
NUM_ITERATIONS = 3
```

change software/ output mode/ thread count:
```python
## tuple of command, output mode, threadcount (where applicable)
METHODS = [

        # ## Pileup Mode
        (run_mpileup, "plp", 1),

        (run_pileuphi, "plp", 1), 
        (run_perbase, "plp", 1),
        (run_parampileup, "plp", 1),

        (run_pileuphi, "plp", 4), 
        (run_perbase, "plp", 4),
        (run_parampileup, "plp", 4),

        (run_pileuphi, "plp", 8), 
        (run_perbase, "plp", 8),
        (run_parampileup, "plp", 8),

        (run_pileuphi, "plp", 12), 
        (run_perbase, "plp", 12),
        (run_parampileup, "plp", 12),

        ## Nucleotide frequency mode
        (run_pileuphi, "histo", 1), 
        (run_pileuphi, "histo", 4), 
        (run_pileuphi, "histo", 8), 
        (run_pileuphi, "histo", 12), 
        ]

```

change files to run on:
```python
FILES = [
    "DRR793869_hg38.bam",
    "SRR19895870.bam",
    "SRR36374445_hg38.bam",
    "SRR30646149_hg38.bam",
    "ERR2756169_merged.bam"
        ]
```

Once you've adjusted this to your liking, run the following to gather benchmarking data:
```bash
python3 bench.py
```


### compare_output.py: output file hash calculation

This script is adjustable similarly to `bench.py` (see above), except `METHODS` differs slightly in structure:
```python
# tuple of run func, ouptut mode, and threads
METHODS = [
        ("mpileup", run_mpileup, "plp", 1, ""), 

        ("pileup-hi", run_pileuphi, "plp", 1),

        ("parallel mpileup", run_parampileup, "plp", 4),
        ("pileup-hi", run_pileuphi, "plp", 4),

        ("parallel mpileup", run_parampileup, "plp", 8),
        ("pileup-hi", run_pileuphi, "plp", 8),

        ("parallel mpileup", run_parampileup, "plp", 12),
        ("pileup-hi", run_pileuphi, "plp", 12)
        ]
```

to run this script: 
```bash
python3 compare_output.py
```


###  compare_size.py: compare output size differences between `pileup-hi`'s 'histo' and 'plp' output modes.

See the previous two sections for what parameters to adjust. This script will output to a sphreadsheet prefixed by `./size_comp*`.

To run: 
```bash
python3 compare_size.py
```
