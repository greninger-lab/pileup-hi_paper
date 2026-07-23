#!/usr/bin/env bash
set -euo pipefail

BAM="${1:-DRR793869_hg38.bam}"
PIECES="${2:-3}"

if [ ! -f "$BAM" ]; then
    echo "Usage: $0 <bam_file> [num_pieces]"
    echo "File not found: $BAM"
    exit 1
fi

BASE="${BAM%.bam}"
SIZE=$(python3 -c "import os; print(os.path.getsize('$BAM'))")
PART_SIZE=$(( (SIZE + PIECES - 1) / PIECES ))

SIZE_GB=$(python3 -c "print(f'{$SIZE/1e9:.1f}')")
PART_GB=$(python3 -c "print(f'{$PART_SIZE/1e9:.1f}')")
echo "Splitting $BAM (${SIZE_GB}G) into $PIECES pieces (~${PART_GB}G each)"

SPLIT_DIR="zenodo_upload"
mkdir -p "$SPLIT_DIR"

split -b "$PART_SIZE" "$BAM" "$SPLIT_DIR/${BASE}.part_"

echo "Generating checksums..."
(
    cd "$SPLIT_DIR"
    for f in "${BASE}.part_"*; do
        b3sum "$f" > "$f.b3sum"
        echo "  $(wc -c < "$f") bytes  $(b3sum "$f" | cut -d' ' -f1)  $f"
    done
)

echo ""
echo "Pieces written to $SPLIT_DIR/"
echo ""
echo "To reconstruct:"
echo "  cat $SPLIT_DIR/${BASE}.part_* > $BAM"
echo "  b3sum -c bam_manifest.b3sum"
