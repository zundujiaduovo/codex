"""Build a flat, complete V12 source overlay that never contains results/."""
from pathlib import Path
import hashlib
import zipfile

ROOT = Path(__file__).resolve().parents[1]
FULL = ROOT / "LEO_QoS_Comparison_v12_uncapped_lexicographic.zip"
PREFIX = "LEO_QoS_Comparison_v12_uncapped_lexicographic/"
UPDATE = ROOT / "V12_complete_source_update.zip"
REQUIRED = {
    "CHECK_V12_INSTALLATION.m", "RUN_V12_ALL_FIGURES.m",
    "matlab/run_leo_v12_diagnostics.m", "matlab/leo_v12_load_report.m",
    "matlab/leo_v12_diagnostic_data.m", "matlab/leo_build_v12_diagnostic_specs.m",
    "matlab/run_leo_v12_greedy_control.m", "matlab/run_leo_v12_proxy_control.m",
    "matlab/run_leo_v12_scaling.m", "INSTALL_V12_UPDATE.md",
}


def build():
    with zipfile.ZipFile(FULL) as source:
        names = {name.removeprefix(PREFIX): name for name in source.namelist()}
        assert all(name.startswith(PREFIX) for name in source.namelist())
        assert REQUIRED <= names.keys(), "Rebuild the full source release first."
        manifest = source.read(names["SOURCE_MANIFEST.sha256"])
        for line in manifest.decode().splitlines():
            digest, relative = line.split("  ", 1)
            payload = source.read(names[relative])
            assert hashlib.sha256(payload).hexdigest() == digest
            assert (ROOT / relative).read_bytes() == payload, "Full source release is stale."
        with zipfile.ZipFile(UPDATE, "w", zipfile.ZIP_DEFLATED, compresslevel=7) as target:
            for relative, original in sorted(names.items()):
                parts = Path(relative).parts
                assert not ({"results", "validation", ".git", "__pycache__"} & set(parts))
                assert not Path(relative).is_absolute() and ".." not in parts
                target.writestr(relative, source.read(original))
    with zipfile.ZipFile(UPDATE) as target:
        assert target.testzip() is None
        assert REQUIRED <= set(target.namelist())
        assert target.read("SOURCE_MANIFEST.sha256") == manifest
    print(f"{UPDATE.name}: {len(names)} complete source/document files, flat layout; no results or validation data.")


if __name__ == "__main__":
    build()
