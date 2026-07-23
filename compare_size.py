from bench import run_pileuphi, run_sambamba, update_report
import subprocess
import pandas as pd
from datetime import datetime

FILES = [
    "ERR2756169_merged.bam",
    "SRR19895870.bam",
    "SRR36374445_hg38.bam",
    "SRR30646149_hg38.bam",
    "DRR793869_hg38.bam",
        ]

# tuple of run func, ouptut mode, and threads
METHODS = [
        (run_pileuphi, "plp", 12),
        (run_pileuphi, "histo", 12),
        (run_sambamba, "plp", 12)
        ]


def compare():
    report = pd.DataFrame()
    now = datetime.now()
    date_time = now.strftime("%m_%d_%Y_%H:%M:%S")
    print(date_time)

    columns = ["File", "Mode", "Size"]

    for file in FILES:
        for method_func, mode, threads in METHODS:
            tool, cmd = method_func(file, mode, threads)

            tool_proc = subprocess.Popen(cmd, stdout=subprocess.PIPE)
            wc_proc = subprocess.Popen(
                ["wc", "-c"], stdin=tool_proc.stdout, stdout=subprocess.PIPE
            )
            tool_proc.stdout.close()
            wc_out, _ = wc_proc.communicate()
            tool_proc.wait()

            size = int(wc_out.strip()) / 1024**3

            report = update_report(report, columns, [file, mode, size])
            report.to_csv("size_comp_" + date_time + ".csv", index=None)

if __name__ == "__main__":
    compare()
