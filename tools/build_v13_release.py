"""Package V13, based on V12, with all MATLAB sources and no result data."""
from pathlib import Path
import hashlib
import zipfile

from build_source_release import DOCS

ROOT = Path(__file__).resolve().parents[1]
NAME = "LEO_QoS_Comparison_v13_128ant_proxy_refinement"


def build():
    sources = [ROOT / name for name in DOCS | {"V13_FROM_V12.md", "V13_ADAPTIVE_STOPPING.md", "V13_SCALING_DIAGNOSIS.md", "V13_128ANT_ITERATIONS.md", "V13_PROXY_REFINEMENT.md"}]
    for pattern in ("*.m", "matlab/*.m", "tools/*.py"):
        sources.extend(ROOT.glob(pattern))
    sources.append(ROOT / ".gitignore")
    sources = sorted(set(sources))
    assert all(path.is_file() for path in sources)
    manifest = "".join(
        f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.relative_to(ROOT).as_posix()}\n"
        for path in sources
    )
    (ROOT / "SOURCE_MANIFEST.sha256").write_text(manifest, encoding="utf-8")
    sources.append(ROOT / "SOURCE_MANIFEST.sha256")
    archive = ROOT / (NAME + ".zip")
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=7) as bundle:
        for path in sources:
            relative = path.relative_to(ROOT)
            assert not {"results", "validation", ".git", "__pycache__"} & set(relative.parts)
            bundle.write(path, NAME + "/" + relative.as_posix())
    with zipfile.ZipFile(archive) as bundle:
        assert bundle.testzip() is None
        for line in manifest.splitlines():
            digest, relative = line.split("  ", 1)
            assert hashlib.sha256(bundle.read(NAME + "/" + relative)).hexdigest() == digest
        for name in ("RUN_V13_64_USERS.m", "V13_SETTINGS.m", "CHECK_V13_INSTALLATION.m", "matlab/leo_v13_parameters.m",
                     "matlab/run_leo_v13_comparison.m", "matlab/leo_reference_users_64.m",
                     "matlab/run_leo_v12_diagnostics.m", "matlab/leo_lexicographic_release.m",
                     "matlab/leo_search_stopping.m", "matlab/leo_method_name.m", "ANALYZE_V13_RESULTS.m",
                     "matlab/leo_cardinality_fairness_bound.m", "matlab/run_leo_v13_candidate_audit.m",
                     "matlab/leo_proxy_tabu_group.m", "matlab/leo_print_bound_explanation.m", "matlab/leo_iteration_only.m",
                     "RUN_V13_PROXY_ABLATIONS.m", "matlab/leo_v13_extra_candidates.m", "matlab/leo_proxy_refinement_options.m"):
            assert NAME + "/" + name in bundle.namelist()
    print(f"{archive.name}: {len(sources)} source/document files, {archive.stat().st_size} bytes; no results.")


if __name__ == "__main__":
    build()
