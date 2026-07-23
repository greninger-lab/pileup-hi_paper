"""Stream pileup-hi and sambamba output, find first line-level difference."""
import subprocess
import sys
import os

BAM = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else "SRR30646149_hg38.bam"
THREADS = 12

pileuphi_cmd = [
    "pileuphi", "plp",
    "-d", "0", "-q", "0", "-Q", "13", "--ff", "1796",
    BAM, "-t", str(THREADS),
]

sambamba_cmd = [
    "sambamba", "mpileup",
    "-t", str(THREADS), BAM,
    "--samtools", "-d 0 -q 0 -Q 13 --ff 1796",
]

proc1 = subprocess.Popen(pileuphi_cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, bufsize=1, text=True)
proc2 = subprocess.Popen(sambamba_cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, bufsize=1, text=True)

line_num = 0
mismatches = []
seen_refs = set()
try:
    while len(mismatches) < 5:
        line1 = proc1.stdout.readline()
        line2 = proc2.stdout.readline()

        if not line1 and not line2:
            break

        line_num += 1

        if line1 != line2:
            ref = line1.split("\t", 3)[2] if "\t" in line1 else ""
            if ref not in seen_refs:
                seen_refs.add(ref)
                mismatches.append(f"Mismatch #{len(mismatches)+1} at line {line_num}, ref={ref}\nPILEUPHI: {line1.rstrip()}\nSAMBAMBA: {line2.rstrip()}\n")

        if line_num % 100000 == 0:
            print(f"  ... {line_num} lines, {len(mismatches)} mismatches so far", file=sys.stderr)

finally:
    proc1.kill()
    proc2.kill()
    proc1.wait()
    proc2.wait()

out = "\n".join(mismatches)
print(out)
print(f"Total lines compared: {line_num}", file=sys.stderr)
