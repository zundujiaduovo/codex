"""Build the V9 source-only MATLAB release; deliberately exclude every result artifact."""
from pathlib import Path
import hashlib
import zipfile

ROOT = Path(__file__).resolve().parents[1]
NAME = "LEO_QoS_Comparison_v9"
DOCS = {
    "README.md", "VERSION.md", "V9_METHOD.md", "REPRODUCIBILITY.md", "FULL_QOS_MODEL.md",
    "THEORETICAL_BOUND.md", "CERTIFICATE_SEARCH.md", "SB_CONVERGENCE.md", "METHODS_AND_METRICS.md", "PAPER_REFERENCE.md",
    "ADAPTIVE_SB.md", "PERIODIC_QOS.md", "PROBLEM_FORMULATION.md", "METHOD.md",
    "FUNCTION_GUIDE.md", "PLOTS.md", "IMPLEMENTATION_STATUS.md", "BENCHMARKS.md",
    "TANGENT_CHORD.md",
}

def build():
    sources = [ROOT / name for name in DOCS]
    for pattern in ("*.m", "matlab/*.m", "tools/*.py"):
        sources.extend(ROOT.glob(pattern))
    sources.append(ROOT / ".gitignore")
    sources = sorted(set(sources))
    assert all(path.is_file() for path in sources)
    manifest = ROOT / "SOURCE_MANIFEST.sha256"
    manifest.write_text("".join(
        f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.relative_to(ROOT).as_posix()}\n"
        for path in sources), encoding="utf-8")
    sources.append(manifest)
    archive = ROOT / (NAME + ".zip")
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=7) as bundle:
        for path in sources:
            bundle.write(path, NAME + "/" + path.relative_to(ROOT).as_posix())
    with zipfile.ZipFile(archive) as bundle:
        assert bundle.testzip() is None
        for name in bundle.namelist():
            relative = Path(name).relative_to(NAME)
            assert not ({"results", "examples", "__pycache__", ".git"} & set(relative.parts))
            assert relative.suffix.lower() not in {
                ".mat", ".csv", ".png", ".pdf", ".fig", ".log", ".zip", ".pyc"
            }
    print(f"{archive.name}: {len(sources)} source/document files, {archive.stat().st_size} bytes; no results.")

if __name__ == "__main__":
    build()
