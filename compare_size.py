from bench import run_pileuphi, update_report
import subprocess
import pandas as pd
from datetime import datetime
import os

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
        (run_pileuphi, "histo", 12)
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

            output_path = f"{tool}_{file}_run_{date_time}"

            # Run tool and write its stdout directly to file (no shell, no ">")
            with open(output_path, "w") as f:
                subprocess.run(cmd, stdout=f, check=True, text=True)

            size = os.path.getsize(output_path) / 1024**3 # get GB

            report = update_report(report, columns, [file, mode, size])
            report.to_csv("size_comp_" + date_time + ".csv", index = None)
            os.remove(output_path)

if __name__ == "__main__":
    compare()
            



