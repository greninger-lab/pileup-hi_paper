import pandas as pd
from pathlib import Path
from datetime import datetime

REPORTS_DIR = Path("reports")
HASHES_DIR = Path("hashes")
MAX_AGE_DAYS = 7


def latest_csv(directory: Path) -> Path | None:
    files = list(directory.glob("*.csv"))
    if not files:
        return None
    return max(files, key=lambda f: f.stat().st_mtime)


def to_xlsx(report_path, hash_path, size_path, output_path):
    with pd.ExcelWriter(output_path, engine="openpyxl") as writer:
        if report_path:
            df = pd.read_csv(report_path)
            df.to_excel(writer, sheet_name="Benchmark", index=False)
        if hash_path:
            df = pd.read_csv(hash_path)
            df.to_excel(writer, sheet_name="Output Hashes", index=False)
        if size_path:
            df = pd.read_csv(size_path)
            df.to_excel(writer, sheet_name="Output Sizes", index=False)


def main():
    report_path = latest_csv(REPORTS_DIR)
    hash_path = latest_csv(HASHES_DIR)
    size_files = sorted(Path(".").glob("size_comp_*.csv"))
    size_path = max(size_files, key=lambda f: f.stat().st_mtime) if size_files else None

    date_str = datetime.now().strftime("%Y%m%d")
    output = Path(f"supp_tables_{date_str}.xlsx")
    to_xlsx(report_path, hash_path, size_path, output)
    print(f"Wrote {output}")


if __name__ == "__main__":
    main()
