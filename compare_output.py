from bench import NO_DEPTH_LIMIT as MAX_DEPTH
import subprocess
import pandas as pd
from datetime import datetime
import os
from pathlib import Path


def run_parampileup(input: str, _mode: str, threads: int, output: str) -> list[str]:
    return ["bash", "para_mpileup.sh", "-t", str(threads), "-d", str(MAX_DEPTH), "-b", input, "-o", output]

def run_pileuphi(input: str, mode: str, threads: int, _output: str) -> list[str]:
    return ["pileuphi", mode, "-d", str(MAX_DEPTH), "-q", "0", "-Q", "13", "--ff", "1796", input, "-t", str(threads)]

def run_mpileup(input: str, _mode: str, _threads: int, _output: str) -> list[str]:
    return ["samtools", "mpileup", "-d", str(MAX_DEPTH), "-q", "0", "-Q", "13", "--ff", "1796", input]

def run_sambamba(input: str, _mode: str, threads: int, _output: str) -> list[str]:
    return ["sambamba", "mpileup", "-t", str(threads), input, "--samtools", "-d 0 -q 0 -Q 13 --ff 1796"]

FILES = [
    "ERR2756169_merged.bam",
    "SRR19895870.bam",
    "SRR36374445_hg38.bam",
    "SRR30646149_hg38.bam",
    "DRR793869_hg38.bam",
        ]


# tuple of run func, ouptut mode, and threads
METHODS = [
        ("pileup-hi", run_pileuphi, "plp", 1),
        ("pileup-hi", run_pileuphi, "plp", 4),
        ("pileup-hi", run_pileuphi, "plp", 8),
        ("pileup-hi", run_pileuphi, "plp", 12),

        ("sambamba", run_sambamba, "plp", 1),
        ("sambamba", run_sambamba, "plp", 4),
        ("sambamba", run_sambamba, "plp", 8),
        ("sambamba", run_sambamba, "plp", 12)
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

    columns = ["Tool", "File", "Threads", "Command", "Hash"]

    out_dir = Path("outputs")
    out_dir.mkdir(exist_ok=True)

    hash_dir = Path("hashes")
    hash_dir.mkdir(exist_ok=True)

    for file in FILES:
        for entry in METHODS:
            name, method_func, mode, threads, *_ = entry

            tool_label = f"{name} {threads} threads"
            output_name = f"{tool_label}_{file}_run_{date_time}"
            output_path = out_dir / output_name
            cmd = method_func(file, mode, threads, str(output_path))

            if name == "parallel mpileup":
                subprocess.run(cmd, check=True, text=True)
                hash_proc = subprocess.run(
                    ["b3sum", str(output_path), "--num-threads", "20"],
                    stdout=subprocess.PIPE, text=True, check=True,
                )
                digest = hash_proc.stdout.strip()
                os.remove(output_path)
            else:
                tool_proc = subprocess.Popen(cmd, stdout=subprocess.PIPE)
                b3sum_proc = subprocess.Popen(
                    ["b3sum", "--num-threads", "20"],
                    stdin=tool_proc.stdout,
                    stdout=subprocess.PIPE,
                    text=True,
                )
                tool_proc.stdout.close()
                digest, _ = b3sum_proc.communicate()
                tool_proc.wait()
                digest = digest.strip()

            report = update_report(report, columns, [name, file, threads, " ".join(cmd), digest])
            report.to_csv("hashes/" + date_time + "_bench_report.csv", index = None)

if __name__ == "__main__":
    compare()
