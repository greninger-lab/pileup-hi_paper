import subprocess
import psutil
import os
import time
import pandas as pd
import pysam
from datetime import datetime

MAX_DEPTH = 10_000_000

class MemoryOveruseException(Exception):
    pass

def run_parampileup(input: str, _mode: str, threads: int) -> tuple[str, list[str]]:
    return "para_mpileup " + str(threads) + " threads", ["bash", "para_mpileup.sh", "-t", str(threads), "-d", str(MAX_DEPTH), "-b", input, "-o", "/dev/null"]

def run_pileuphi(input: str, mode: str, threads: int) -> tuple[str, list[str]]:
    return "pileuphi " + str(threads) + " threads", ["pileuphi", mode, "-d", str(MAX_DEPTH), input, "-t", str(threads)]

def run_mpileup(input: str, _mode: str, _threads: int) -> tuple[str, list[str]]:
    return "samtools mpileup", ["samtools", "mpileup", "-d", str(MAX_DEPTH), input]

def run_perbase(input: str, _mode: str, threads: int) -> tuple[str, list[str]]:
    return "perbase base-depth " + str(threads) + " threads", ["perbase", "base-depth", input, "--max-depth", str(MAX_DEPTH), "-t", str(threads)]

NUM_ITERATIONS = 3

FILES = [
    "DRR793869_hg38.bam",
    "SRR19895870.bam",
    "SRR36374445_hg38.bam",
    "SRR30646149_hg38.bam",
    "ERR2756169_merged.bam"
        ]

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

MAX_TIME = 100800 # 7 days

def update_report(report, columns, dat):
    minireport = dict()
    for col, d in zip(columns, dat):
        minireport[col] = [d]

    report = pd.concat([report, pd.DataFrame(minireport)], ignore_index=True)
    return report


def get_reads(file):
    mapped_reads = 0

    try:

        mapped_reads += int(pysam.view("-@ 8", "-F 4", "-c", file))
    except pysam.utils.SamtoolsError:
        mapped_reads = -1

    return mapped_reads


def get_mem_usage(pid):
    try:
        process = psutil.Process(pid)
        children = process.children(recursive=True)

        memory_gb = process.memory_info().rss / 1024**3

        ## get mem of child procs too (looking at you, JVM)
        for c in children:
            try:
                memory_gb += c.memory_info().rss / 1024**3
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass

        return memory_gb

    except psutil.NoSuchProcess:
        return 0.0


def monitor_cmd(cmd, maxtime):
    process = subprocess.Popen(cmd, stdout=subprocess.DEVNULL)
    start_time = time.time()

    pid = process.pid
    peak_memory_usage = 0.0
    parent = psutil.Process(pid)

    try:
        while True:
            if process.poll() is not None:
                break

            memory_usage = get_mem_usage(pid)
            if memory_usage > peak_memory_usage:
                peak_memory_usage = memory_usage

            # if memory_usage > maxmem:
            runtime = time.time() - start_time
            if runtime > maxtime:
                proc = psutil.Process(pid)
                for c in proc.children(recursive=True):
                    c.kill()

                proc.kill()
                raise MemoryOveruseException(
                    f"\033[31mMaximum runtime of {maxtime} seconds exceeded! Killing process...\033[0m"
                )

            print(
                f"\033[31mCurrent Peak Memory Usage: {peak_memory_usage:.2f} GB\033[0m",
                end="\r",
            )

            time.sleep(0.1)  # Sleep for a while before checking again

    except MemoryOveruseException as e:
        print(e)
        elapsed_time = time.time() - start_time

        return peak_memory_usage, elapsed_time, "Terminated"

    elapsed_time = time.time() - start_time

    print(
        f"\033[31mElapsed Time: {elapsed_time:.2f} seconds | Peak Memory Usage: {peak_memory_usage:.2f} GB\033[0m",
        flush=True,
    )

    return (peak_memory_usage, elapsed_time, "Completed")


def main():
    report = pd.DataFrame()
    now = datetime.now()
    date_time = now.strftime("%m/%d/%Y, %H:%M:%S").replace("/", "_").replace(", ", "_")
    print(date_time)

    columns = [
        "Tool",
        "Mode",
        "File",
        "Peak memory used",
        "Runtime",
        "Status",
        "Input reads (mapped)",
        "Iteration",
        ]

    for col in columns:
        report[col] = ""

    for file in FILES:
        for iteration in range(NUM_ITERATIONS):
           for method_func, mode, threads in METHODS:
               tool, cmd = method_func(file, mode, threads)
               print(" ".join(cmd))

               reads_mapped = get_reads(file)

               mem, time, status = monitor_cmd(cmd, MAX_TIME)

               if status == "Terminated":
                   break;

               report = update_report(report, columns, [tool, mode, file, mem, time, status, reads_mapped, iteration])
               report.to_csv("reports/" + date_time + "_bench_report.csv", index = None)

if __name__ == "__main__":
               main()
