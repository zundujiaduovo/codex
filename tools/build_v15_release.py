"""Full V15 package and flat complete update, retaining repaired V14 sources."""
from pathlib import Path
import hashlib
import tempfile
import zipfile
from build_source_release import DOCS

ROOT = Path(__file__).resolve().parents[1]
NAME = 'LEO_QoS_Comparison_v15_from_v14_repaired_search_certified_bounds'


def build():
    docs = DOCS | {'V13_FROM_V12.md', 'V13_ADAPTIVE_STOPPING.md',
        'V13_SCALING_DIAGNOSIS.md', 'V13_128ANT_ITERATIONS.md', 'V13_PROXY_REFINEMENT.md',
        'V14_FROM_V13.md', 'INSTALL_V14_UPDATE.md', 'V15_FROM_V14.md', 'INSTALL_V15_UPDATE.md'}
    paths = {ROOT / name for name in docs}
    for pattern in ('*.m', 'matlab/*.m', 'tools/*.py'):
        paths.update(ROOT.glob(pattern))
    paths.add(ROOT / '.gitignore')
    sources = sorted(paths)
    manifest = ''.join(f'{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.relative_to(ROOT).as_posix()}\n' for path in sources)
    (ROOT / 'SOURCE_MANIFEST.sha256').write_text(manifest, encoding='utf-8')
    sources.append(ROOT / 'SOURCE_MANIFEST.sha256')
    required = {'RUN_V15_ALL.m', 'RUN_V15_BOUNDS.m', 'V15_SETTINGS.m', 'V15_BOUND_SETTINGS.m',
        'CHECK_V15_INSTALLATION.m', 'matlab/leo_v15_price_block.m', 'matlab/leo_v15_master.m',
        'matlab/leo_v15_certificate.m', 'matlab/run_leo_v15_bounds.m',
        'RUN_V14_STAGE2_REPAIR.m', 'matlab/leo_v14_trust_path.m',
        'matlab/leo_v14_run_price_phase.m', 'matlab/run_leo_v14_stage2_repair.m'}
    for filename, prefix in ((NAME+'.zip', NAME+'/'), ('V15_complete_source_update.zip', '')):
        archive = ROOT / filename
        with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED, compresslevel=7) as bundle:
            for path in sources:
                relative = path.relative_to(ROOT).as_posix()
                assert not {'results', 'validation', '.git', '__pycache__'} & set(Path(relative).parts)
                bundle.write(path, prefix+relative)
        with zipfile.ZipFile(archive) as bundle:
            assert bundle.testzip() is None
            assert all(prefix+name in bundle.namelist() for name in required)
            for line in manifest.splitlines():
                digest, relative = line.split('  ', 1)
                assert hashlib.sha256(bundle.read(prefix+relative)).hexdigest() == digest
            if not prefix:
                with tempfile.TemporaryDirectory() as test:
                    sentinel = Path(test) / 'results' / 'keep.mat'
                    sentinel.parent.mkdir(); sentinel.write_bytes(b'preserve saved results')
                    bundle.extractall(test)
                    assert sentinel.read_bytes() == b'preserve saved results'
                    assert (Path(test) / 'matlab/leo_v15_certificate.m').is_file()
        print(f'{filename}: {len(sources)} files, {archive.stat().st_size} bytes; hashes verified, V14 phase-2 repair included.')


if __name__ == '__main__':
    build()
