import hashlib
import json
import subprocess
from pathlib import Path

BAMS = ["DRR793869_hg38.bam", "SRR19895870.bam", "SRR36374445_hg38.bam",
        "SRR30646149_hg38.bam", "ERR2756169_merged.bam"]

BENCH_SCRIPT = "bench.py"
COMPARE_OUTPUT_SCRIPT = "compare_output.py"
COMPARE_SIZE_SCRIPT = "compare_size.py"
METRICS_SCRIPT = "get_metrics.sh"

MANIFEST = "bam_manifest.b3sum"

REPORTS_DIR = "reports"
HASHES_DIR = "hashes"

# Zenodo records mapping to the BAM files they contain
ZENODO_BAM_RECORDS = {
    "19612806": ["SRR36374445_hg38.bam"],
    "19613934": ["SRR19895870.bam", "SRR30646149_hg38.bam"],
    "19614468": ["ERR2756169_merged.bam"],
}

# DRR is split into 3 pieces across 3 records
ZENODO_DRR_PART_RECORDS = [
    ("21480618", "DRR793869_hg38.part_aa"),
    ("21480649", "DRR793869_hg38.part_ab"),
    ("21480662", "DRR793869_hg38.part_ac"),
]

# All non-DRR BAM files (downloaded directly from Zenodo)
ZENODO_BAM_FILES = []
for bams in ZENODO_BAM_RECORDS.values():
    ZENODO_BAM_FILES.extend(bams)

all_bam_checksums = {}
with open(MANIFEST) as f:
    for line in f:
        parts = line.strip().split()
        if len(parts) >= 2:
            cksum = parts[0]
            fname = parts[1].lstrip("*")
            all_bam_checksums[fname] = cksum


def _b3sum(path):
    return hashlib.file_digest(open(path, "rb"), "blake2b").hexdigest()


rule all:
    input:
        [f"reports/{b}.done" for b in BAMS],
        [f"hashes/{b}.done" for b in BAMS],
        expand("size_comp_{b}.done", b=BAMS),
        expand("alignment_metrics_{b}.done", b=BAMS),
        "figures/_done",

rule download_all:
    """Download all BAMs from Zenodo (non-DRR and DRR pieces)."""
    input:
        ZENODO_BAM_FILES + ["DRR793869_hg38.part_aa", "DRR793869_hg38.part_ab", "DRR793869_hg38.part_ac"],


# ---------------------------------------------------------------------------
# Download BAMs from Zenodo (non-DRR)
# ---------------------------------------------------------------------------

rule download_bams:
    """Download all BAMs from Zenodo records (filters to .bam/.bai only)."""
    output:
        bams = ZENODO_BAM_FILES,
    run:
        for record_id, bams in ZENODO_BAM_RECORDS.items():
            api_url = f"https://zenodo.org/api/records/{record_id}"
            result = subprocess.run(
                ["curl", "-sL", api_url], capture_output=True, text=True, check=True
            )
            files = json.loads(result.stdout)["files"]
            for f in files:
                key = f["key"]
                if not (key.endswith(".bam") or key.endswith(".bai")):
                    continue
                dl_url = f["links"]["download"]
                subprocess.run(["curl", "-L", "-o", key, dl_url], check=True)


# ---------------------------------------------------------------------------
# Download and reconstruct DRR
# ---------------------------------------------------------------------------

rule download_drr_parts:
    """Download the three DRR pieces from Zenodo."""
    output:
        parts = ["DRR793869_hg38.part_aa", "DRR793869_hg38.part_ab", "DRR793869_hg38.part_ac"],
    run:
        for rec_id, part_name in ZENODO_DRR_PART_RECORDS:
            api_url = f"https://zenodo.org/api/records/{rec_id}"
            result = subprocess.run(
                ["curl", "-sL", api_url], capture_output=True, text=True, check=True
            )
            files = json.loads(result.stdout)["files"]
            for f in files:
                if f["key"] == part_name:
                    dl_url = f["links"]["download"]
                    subprocess.run(["curl", "-L", "-o", part_name, dl_url], check=True)
                    break


rule reconstruct_drr:
    """Concatenate DRR pieces into DRR793869_hg38.bam and verify checksum."""
    input:
        "DRR793869_hg38.part_aa",
        "DRR793869_hg38.part_ab",
        "DRR793869_hg38.part_ac",
    output:
        "DRR793869_hg38.bam",
    run:
        subprocess.run(
            ["bash", "-c", "cat DRR793869_hg38.part_* > DRR793869_hg38.bam"],
            check=True,
        )
        for p in Path(".").glob("DRR793869_hg38.part_*"):
            p.unlink()
        # Verify reconstructed BAM matches manifest
        expected = all_bam_checksums["DRR793869_hg38.bam"]
        actual = _b3sum("DRR793869_hg38.bam")
        if actual != expected:
            raise ValueError(
                f"DRR reconstruction failed: checksum mismatch "
                f"(expected {expected}, got {actual})"
            )


# ---------------------------------------------------------------------------
# Index and verify
# ---------------------------------------------------------------------------

rule ensure_index:
    input:
        bam = "{bam}",
    output:
        bai = "{bam}.bai",
    run:
        bai_path = Path(str(output.bai))
        if not bai_path.exists():
            subprocess.run(["samtools", "index", str(input.bam)], check=True)


rule verify_download:
    """Verify BAM checksums against manifest (bai is regenerated locally)."""
    input:
        bam = "{bam}",
        bai = "{bam}.bai",
    output:
        touch("{bam}.verified"),
    params:
        fname = lambda w: w.bam,
    run:
        expected = all_bam_checksums[params.fname]
        actual = _b3sum(str(input.bam))
        if actual != expected:
            raise ValueError(
                f"Checksum mismatch for {params.fname}: expected {expected}, got {actual}"
            )


# ---------------------------------------------------------------------------
# Analysis rules
# ---------------------------------------------------------------------------

rule bench:
    input:
        verified = "{bam}.verified",
    output:
        done = touch(REPORTS_DIR + "/{bam}.done"),
    run:
        subprocess.run(["python", BENCH_SCRIPT], check=True)


rule compare_output:
    input:
        verified = "{bam}.verified",
    output:
        done = touch(HASHES_DIR + "/{bam}.done"),
    run:
        subprocess.run(["python", COMPARE_OUTPUT_SCRIPT], check=True)


rule compare_size:
    input:
        verified = "{bam}.verified",
    output:
        done = touch("size_comp_{bam}.done"),
    run:
        subprocess.run(["python", COMPARE_SIZE_SCRIPT], check=True)


rule alignment_metrics:
    input:
        verified = "{bam}.verified",
        bam = "{bam}",
    output:
        done = touch("alignment_metrics_{bam}.done"),
    run:
        subprocess.run(["bash", METRICS_SCRIPT], check=True)


rule figures:
    input:
        bench = [REPORTS_DIR + "/" + b + ".done" for b in BAMS],
        hashes_comp = [HASHES_DIR + "/" + b + ".done" for b in BAMS],
        size_comp = ["size_comp_" + b + ".done" for b in BAMS],
    output:
        touch("figures/_done"),
    run:
        subprocess.run(
            ["Rscript", "-e", 'rmarkdown::render("bench.Rmd")'], check=True
        )


rule clean:
    run:
        import shutil
        for d in [REPORTS_DIR, HASHES_DIR, "results", "figures", "outputs", "_download"]:
            shutil.rmtree(d, ignore_errors=True)
        for p in Path(".").glob("size_comp_*.csv"):
            p.unlink()
        for p in Path(".").glob("*.done"):
            p.unlink()
        for p in Path(".").glob("alignment_metrics_*.done"):
            p.unlink()
