"""Complete V14 source package; no simulation results or historical archives."""
from pathlib import Path
import hashlib
import zipfile
from build_source_release import DOCS

ROOT = Path(__file__).resolve().parents[1]
NAME = 'LEO_QoS_Comparison_v14_from_v13_fairness_coordination'


def build():
    documents = DOCS | {'V13_FROM_V12.md', 'V13_ADAPTIVE_STOPPING.md',
        'V13_SCALING_DIAGNOSIS.md', 'V13_128ANT_ITERATIONS.md', 'V13_PROXY_REFINEMENT.md', 'V14_FROM_V13.md'}
    paths = {ROOT / name for name in documents}
    for pattern in ('*.m', 'matlab/*.m', 'tools/*.py'):
        paths.update(ROOT.glob(pattern))
    paths.add(ROOT / '.gitignore')
    sources = sorted(paths)
    manifest = ''.join(f'{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.relative_to(ROOT).as_posix()}\n' for path in sources)
    (ROOT / 'SOURCE_MANIFEST.sha256').write_text(manifest, encoding='utf-8')
    sources.append(ROOT / 'SOURCE_MANIFEST.sha256')
    archive = ROOT / (NAME + '.zip')
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED, compresslevel=7) as bundle:
        for path in sources:
            relative = path.relative_to(ROOT)
            assert not {'results', 'validation', '.git', '__pycache__'} & set(relative.parts)
            bundle.write(path, NAME + '/' + relative.as_posix())
    with zipfile.ZipFile(archive) as bundle:
        assert bundle.testzip() is None
        for line in manifest.splitlines():
            digest, relative = line.split('  ', 1)
            assert hashlib.sha256(bundle.read(NAME + '/' + relative)).hexdigest() == digest
        for relative in ('RUN_V14_ALL.m', 'RUN_V14_CONTROLS.m', 'V14_SETTINGS.m',
                         'matlab/leo_v14_run_price_phase.m', 'matlab/leo_v14_coupled_bound.m',
                         'RUN_V14_STAGE2_REPAIR.m', 'matlab/leo_v14_trust_path.m'):
            assert NAME + '/' + relative in bundle.namelist()
    print(f'{archive.name}: {len(sources)} source/document files, {archive.stat().st_size} bytes; no results.')


if __name__ == '__main__':
    build()
