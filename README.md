# pileup-hi — benchmarking and output comparison

This repository contains the benchmarking and output-comparison code for the manuscript: *"pileup-hi: an ultra-high throughput, customizable pileup program for large datasets"*.

For the pileup-hi tool itself (installation, usage, options), see [the main repo](https://github.com/epiliper/pileup-hi).

---

## Quick start

```bash
# 1. Set up the pixi environment (installs all dependencies)
pixi install

# 2. Download BAMs (or verify existing ones)
pixi run snakemake-dl

# 3. Run the full analysis pipeline
pixi run all
```

## Requirements

- **pixi** — package manager; install via `curl -fsSL https://pixi.sh/install.sh | sh`
- **1.5+ TB** free disk space for BAMs and outputs
- **macOS** (tested on Sequoia 15.7.4) or Linux
- **Homebrew** (macOS only, for sambamba workaround — see below)

## Setup

### pixi environment

All dependencies (samtools, perbase, b3sum, bam-readcount, sambamba, python packages, etc.) are pinned in `pixi.toml` and installed via:

```bash
pixi install
pixi run setup
```

`samtools mpileup` is used as the reference tool. `compare_output.py` and `bench.py` compare pileup-hi output directly against samtools mpileup.

### BAM files

Five datasets are used in the manuscript:

| BAM | Size | Source |
|-----|------|--------|
| `ERR2756169_merged.bam` | 7.2 G | SRA |
| `SRR19895870.bam` | 8.4 G | SRA |
| `SRR36374445_hg38.bam` | 38 G | SRA |
| `SRR30646149_hg38.bam` | 36 G | SRA |
| `DRR793869_hg38.bam` | 103 G | SRA |

BAMs and their indices can be downloaded from Zenodo (see `ZENODO.md` for record URLs) via `snakemake`:

```bash
pixi run snakemake-dl
```

A BLAKE3 checksum manifest is provided in `bam_manifest.b3sum`:

```bash
b3sum -c bam_manifest.b3sum
```

### macOS sambamba workaround

The conda sambamba binary segfaults on macOS for us. `setup_sambamba.sh` automatically detects this and symlinks the Homebrew sambamba (1.0.1) into the pixi environment. This is run automatically as a dependency of `bench`, `compare-output`, and `compare-size`.

If you don't use Homebrew, install sambamba 1.0.1 manually and symlink it to `~/.pixi/envs/default/bin/sambamba`.

## Running the analysis

### All at once

```bash
pixi run all
```

This runs benchmarking, output comparison, size comparison, and alignment metrics.

### Individual steps

#### bench.py — runtime and peak memory

Records wall-clock time and peak RSS for each tool on each BAM. Results written to `reports/`.

```bash
pixi run bench
```

By default, this runs all tools in triplicate:
- **pileup-hi plp**: 1, 4, 8, 12 threads
- **samtools mpileup**: 1 thread
- **perbase base-depth**: 1, 4, 8, 12 threads (multiple configurations: default, `-F 0`, `-c 50000`, `-C 1.0`)
- **parallel mpileup** (`para_mpileup.sh`): 1, 4, 8, 12 threads
- **sambamba mpileup**: 1, 4, 8, 12 threads
- **bam-readcount**: 1 thread
- **pileup-hi histo**: 1, 4, 8, 12 threads

To change the set of tools, BAMs, or iteration count, edit the `METHODS`, `FILES`, and `NUM_ITERATIONS` variables at the top of `bench.py`.

#### compare_output.py — output hash comparison

Pipes each tool's output through `b3sum` and records the digest. Used to verify deterministic output across thread counts and equivalence to samtools mpileup.

```bash
pixi run compare-output
```

Results are written to `hashes/` as timestamped CSV files.

#### compare_size.py — output size comparison

Compares the compressed output size of `plp` vs `histo` mode for pileup-hi.

```bash
pixi run compare-size
```

Results written to `size_comp_*.csv`.

#### Alignment metrics

```bash
pixi run metrics
```

Runs `get_metrics.sh` to compute depth, coverage, and related metrics.

#### Figures and supplementary tables

```bash
pixi run figures
pixi run supp-tables
```

## Tools compared

| Tool | Version | Command |
|------|---------|---------|
| **pileup-hi** | 0.9.2 | `pileuphi` |
| **samtools mpileup** | 1.23 | `samtools mpileup` |
| **sambamba mpileup** | 1.0.1 | `sambamba mpileup` |
| **perbase base-depth** | 1.2.0 | `perbase base-depth` |
| **parallel mpileup** | — | `para_mpileup.sh` (shell wrapper around `samtools mpileup`) |
| **bam-readcount** | latest | `bam-readcount` |

### Flag consistency

All tools are run with equivalent flags where possible:

| Flag | All tools | Meaning |
|------|-----------|---------|
| `-d 0` | pileup-hi, samtools, perbase, para_mpileup | Unlimited depth |
| `-q 0` | pileup-hi, samtools, sambamba | No minimum mapping quality |
| `-Q 13` | pileup-hi, samtools, sambamba | Minimum base quality 13 |
| `--ff 1796` | pileup-hi, samtools, sambamba | Exclude UNMAP, SECONDARY, QCFAIL, DUP |
| `-F 3844` | perbase (default) | Exclude UNMAPPED, SECONDARY, QCFAIL, DUPLICATE, SUPPLEMENTARY |

bam-readcount uses `--min-mapping-quality=0 --min-base-quality=0 --max-count=0`.

## Output files
| File | Description |
|------|-------------|
| `reports/bench_*.csv` | Runtime and memory benchmarks |
| `hashes/*.csv` | Output hash results |
| `size_comp_*.csv` | Output size comparisons |
| `hashes_2026Feb27.csv` | Published output hashes (paper) |
| `size_comp_2026Mar31.csv` | Published size comparison (paper) |
| `bench_report_2026Mar30.csv` | Published benchmark data (paper) |

## Scripts

| Script | Description |
|--------|-------------|
| `bench.py` | Runtime and memory benchmarking |
| `compare_output.py` | Output hash comparison (pileup-hi vs sambamba) |
| `compare_size.py` | Output size comparison (plp vs histo) |
| `scripts/setup_sambamba.sh` | macOS sambamba workaround |
| `scripts/compare_streams.py` | Line-by-line stream comparison of two tools |
| `para_mpileup.sh` | Parallel samtools mpileup wrapper |
| `get_metrics.sh` | Alignment metrics computation |
| `make_supp_tables.py` | Supplementary table generation |
| `bench.Rmd` | Figure generation (Rmarkdown) |
| `metrics.Rmd` | Metrics figure generation (Rmarkdown) |
| `aln.sh` | BAM generation from FASTQ |
| `dl.sh` | FASTQ download from SRA |
