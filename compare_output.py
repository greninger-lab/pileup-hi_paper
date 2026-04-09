from bench import MAX_DEPTH
import subprocess
import pandas as pd
from datetime import datetime
import os
from pathlib import Path


def run_parampileup(input: str, _mode: str, threads: int, output: str) -> list[str]:
    return ["bash", "para_mpileup.sh", "-t", str(threads), "-d", str(MAX_DEPTH), "-b", input, "-o", output]

def run_pileuphi(input: str, mode: str, threads: int, _output: str) -> list[str]:
    return ["pileuphi", mode, "-d", str(MAX_DEPTH), input, "-t", str(threads)]

def run_mpileup(input: str, _mode: str, _threads: int, _output: str) -> list[str]:
    return ["samtools", "mpileup", "-d", str(MAX_DEPTH), input]

FILES = [
    "ERR2756169_merged.bam",
    "SRR19895870.bam",
    "SRR36374445_hg38.bam",
    "SRR30646149_hg38.bam",
    "DRR793869_hg38.bam",
        ]


# tuple of run func, ouptut mode, and threads
METHODS = [
        ("mpileup", run_mpileup, "plp", 1, ""), # keep mpileup at index 0

        ("pileup-hi", run_pileuphi, "plp", 1),

        ("parallel mpileup", run_parampileup, "plp", 4),
        ("pileup-hi", run_pileuphi, "plp", 4),

        ("parallel mpileup", run_parampileup, "plp", 8),
        ("pileup-hi", run_pileuphi, "plp", 8),

        ("parallel mpileup", run_parampileup, "plp", 12),
        ("pileup-hi", run_pileuphi, "plp", 12)
        ]

def update_report(report, columns, dat):
    minireport = dict()
    for col, d in zip(columns, dat):
        minireport[col] = [d]

    report = pd.concat([report, pd.DataFrame(minireport)], ignore_index=True)
    return report

def compare():
    report = pd.DataFrame()
    now = datetime.now()
    date_time = now.strftime("%m_%d_%Y_%H:%M:%S")
    print(date_time)

    columns = ["Tool", "File", "Threads", "Hash"]

    out_dir = Path("outputs")
    out_dir.mkdir(exist_ok=True)

    hash_dir = Path("hashes")
    hash_dir.mkdir(exist_ok=True)

    for file in FILES:
        for name, method_func, mode, threads in METHODS:

            output_name = f"{name + " " + str(threads) + " threads"}_{file}_run_{date_time}"
            output_path = out_dir / output_name
            cmd = method_func(file, mode, threads, str(output_path)) # cmd is a list of args

            # Run tool and write its stdout directly to file (no shell, no ">")
            if name == "parallel mpileup":
                subprocess.run(cmd, check = True, text = True)
            else:
                with output_path.open("w") as f:
                    subprocess.run(cmd, stdout=f, check=True, text=True)

            # Hash the output file
            hash_proc = subprocess.run(
                ["b3sum", str(output_path), "--num-threads", "20"],
                stdout=subprocess.PIPE,
                text=True,
                check=True,
            )
            digest = hash_proc.stdout.strip()

            report = update_report(report, columns, [name, file, threads, digest])
            report.to_csv("hashes/" + date_time + "_bench_report.csv", index = None)
            os.remove(output_path)

if __name__ == "__main__":
    compare()
