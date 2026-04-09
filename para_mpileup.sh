#!/usr/bin/env bash
set -euo pipefail

BAMS=()
OUTPUT="output.pileup"
REF=""
THREADS=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)
DEPTH=10000000
MIN_CHUNK=250000
BASE_QUAL=0
MAP_QUAL=0
EXTRA_FLAGS=""
SCRATCH="${TMPDIR:-/tmp}"

while getopts ":b:o:r:t:m:d:q:Q:f:k:h" opt; do
    case $opt in
        b) BAMS+=("$OPTARG") ;;
        o) OUTPUT="$OPTARG" ;;
        r) REF="$OPTARG" ;;
        t) THREADS="$OPTARG" ;;
        m) MIN_CHUNK="$OPTARG" ;;
        d) DEPTH="$OPTARG" ;;
        q) BASE_QUAL="$OPTARG" ;;
        Q) MAP_QUAL="$OPTARG" ;;
        f) EXTRA_FLAGS="$OPTARG" ;;
        k) SCRATCH="$OPTARG" ;;
        :) echo "[ERROR] Option -$OPTARG requires an argument." >&2; exit 1 ;;
        \?) echo "[ERROR] Unknown option: -$OPTARG" >&2; exit 1 ;;
    esac
done

if [ ${#BAMS[@]} -eq 0 ]; then
    echo "[ERROR] At least one BAM file must be provided with -b." >&2; exit 1
fi

for bam in "${BAMS[@]}"; do
    [ -f "$bam" ] || { echo "[ERROR] BAM not found: $bam" >&2; exit 1; }
    [ -f "${bam}.bai" ] || [ -f "${bam%.bam}.bai" ] \
        || { echo "[ERROR] BAM index not found for: $bam" >&2; exit 1; }
done

if [ -n "$REF" ] && [ ! -f "$REF" ]; then
    echo "[ERROR] Reference FASTA not found: $REF" >&2; exit 1
fi

# make temp files dir
WORKDIR=$(mktemp -d "${SCRATCH}/mpileup_XXXXXX")
trap 'echo "[INFO] Cleaning up ${WORKDIR}"; rm -rf "${WORKDIR}"' EXIT

echo "[INFO] Work directory : ${WORKDIR}"
echo "[INFO] Threads        : ${THREADS}"
echo "[INFO] Min chunk size : ${MIN_CHUNK} bp"
echo "[INFO] Depth          : ${DEPTH}"
echo "[INFO] BAM files      : ${BAMS[*]}"
echo "[INFO] Output         : ${OUTPUT}"
echo ""

> "${OUTPUT}"

REF_FLAG=""
if [ -n "$REF" ]; then
    REF_FLAG="-f ${REF}"
fi
BAM_ARGS="${BAMS[*]}"

run_chunk() {
    local chrom="$1"
    local start="$2"
    local end="$3"
    local chunk_dir="$4"
    local region="${chrom}:${start}-${end}"
    local outfile
    outfile="${chunk_dir}/$(printf '%012d' "${start}").pileup"

    # shellcheck disable=SC2086
    samtools mpileup \
        ${REF_FLAG} \
        -r "${region}" \
        -d "${DEPTH}" \
        ${EXTRA_FLAGS} \
        ${BAM_ARGS} \
        > "${outfile}" \
        2>> "${WORKDIR}/errors.log"
}

export -f run_chunk
export REF_FLAG BAM_ARGS MAP_QUAL BASE_QUAL EXTRA_FLAGS WORKDIR

## get all chromosome names
echo "[INFO] Reading chromosome list from BAM header..."

CHROM_SIZES="${WORKDIR}/chrom_sizes.txt"
samtools view -H "${BAMS[0]}" \
    | awk '/^@SQ/ {
        name=""; len=0
        for (i = 2; i <= NF; i++) {
            if ($i ~ /^SN:/) name = substr($i, 4)
            if ($i ~ /^LN:/) len  = substr($i, 4) + 0
        }
        if (name != "" && len > 0) print name "\t" len
      }' > "${CHROM_SIZES}"

TOTAL_CHROMS=$(wc -l < "${CHROM_SIZES}")
if [ "$TOTAL_CHROMS" -eq 0 ]; then
    echo "[ERROR] No sequences found in BAM header." >&2; exit 1
fi

TOTAL_BASES=$(awk '{s += $2} END {print s}' "${CHROM_SIZES}")
echo "[INFO] Sequences found : ${TOTAL_CHROMS}  |  Total bases : ${TOTAL_BASES}"
echo ""


# now we process one chromosome at a time...
CHROM_NUM=0

while read -r CHROM CHROM_LEN; do
    CHROM_NUM=$(( CHROM_NUM + 1 ))
    echo "[INFO] Chromosome ${CHROM_NUM}/${TOTAL_CHROMS}: ${CHROM} (${CHROM_LEN} bp)"

    EFFECTIVE_CHUNK=$(awk -v len="${CHROM_LEN}" \
                          -v threads="${THREADS}" \
                          -v min="${MIN_CHUNK}" \
                      'BEGIN {
                          ideal = int((len + threads - 1) / threads)
                          chunk = (ideal > min) ? ideal : min
                          print chunk
                      }')
    NUM_CHUNKS=$(awk -v len="${CHROM_LEN}" -v chunk="${EFFECTIVE_CHUNK}" \
                 'BEGIN { print int((len + chunk - 1) / chunk) }')

    echo "[INFO]   Chunk size : ${EFFECTIVE_CHUNK} bp  |  Chunks : ${NUM_CHUNKS}"

    CHROM_REGIONS="${WORKDIR}/regions_${CHROM}.txt"
    awk -v chrom="${CHROM}" \
        -v clen="${CHROM_LEN}" \
        -v chunk="${EFFECTIVE_CHUNK}" \
    'BEGIN {
        start = 1
        while (start <= clen) {
            end = start + chunk - 1
            if (end > clen) end = clen
            print chrom "\t" start "\t" end
            start = end + 1
        }
    }' > "${CHROM_REGIONS}"

    # make tempdir
    CHUNK_DIR="${WORKDIR}/chunks_${CHROM}"
    mkdir -p "${CHUNK_DIR}"

    # run the threads
    parallel --jobs "${THREADS}" \
             --colsep '\t' \
             run_chunk {1} {2} {3} "${CHUNK_DIR}" \
             < "${CHROM_REGIONS}"

##!/usr/bin/env bash
#set -euo pipefail
#$(declare -f run_chunk)
#export REF_FLAG="${REF_FLAG}"
#export BAM_ARGS="${BAM_ARGS}"
#export MAP_QUAL="${MAP_QUAL}"
#export BASE_QUAL="${BASE_QUAL}"
#export EXTRA_FLAGS="${EXTRA_FLAGS}"
#export WORKDIR="${WORKDIR}"
#CHUNK_DIR="${CHUNK_DIR}"
#LINE="\$1"
#CHROM=\$(echo "\$LINE"  | awk -F'\t' '{print \$1}')
#START=\$(echo "\$LINE"  | awk -F'\t' '{print \$2}')
#END=\$(echo "\$LINE"    | awk -F'\t' '{print \$3}')
#run_chunk "\$CHROM" "\$START" "\$END" "\$CHUNK_DIR"
#WRAPPER_EOF
        # chmod +x "${WRAPPER}"
        # awk '{print $1 "\t" $2 "\t" $3}' "${CHROM_REGIONS}" \
        #     | xargs -P "${THREADS}" -I{} "${WRAPPER}" {}
    # fi

    # -- 2e. Merge all chunks in positional order, append to final output ----
    echo "[INFO]   Merging ${NUM_CHUNKS} chunk(s) into ${OUTPUT}..."
    cat "${CHUNK_DIR}"/*.pileup >> "${OUTPUT}"

    # -- 2f. Delete chunk files before moving to the next chromosome ---------
    rm -rf "${CHUNK_DIR}" "${CHROM_REGIONS}"
    echo "[INFO]   Temp files for ${CHROM} removed."
    echo ""

done < "${CHROM_SIZES}"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
LINES=$(wc -l < "${OUTPUT}")
echo "[INFO] Complete. Output : ${OUTPUT}  (${LINES} pileup lines)"

if [ -s "${WORKDIR}/errors.log" ]; then
    echo "[WARN] samtools produced warnings/errors -- see below:"
    cat "${WORKDIR}/errors.log" >&2
fi
