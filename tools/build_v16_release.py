"""One clean V16 source archive, checked against the complete live dependency graph."""
from pathlib import Path
import hashlib
import zipfile
from dependencies_v16 import check, ROOT

NAME='LEO_QoS_V16_parallel64_convergence'


def build():
    count=check(ROOT)
    sources=sorted(set(ROOT.glob('*.m')) | set((ROOT/'matlab').glob('*.m')) |
                   set((ROOT/'tools').glob('*.py')) | {ROOT/name for name in ('README.md','VERSION.md','V16_CHANGELOG.md','.gitignore')})
    manifest=''.join(f'{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.relative_to(ROOT).as_posix()}\n' for p in sources)
    (ROOT/'SOURCE_MANIFEST.sha256').write_text(manifest,encoding='utf-8')
    sources.append(ROOT/'SOURCE_MANIFEST.sha256')
    archive=ROOT/(NAME+'.zip')
    with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=7) as bundle:
        for path in sources:
            relative=path.relative_to(ROOT).as_posix()
            assert not {'results','validation','.git','__pycache__'} & set(Path(relative).parts)
            bundle.write(path,NAME+'/'+relative)
    with zipfile.ZipFile(archive) as bundle:
        assert bundle.testzip() is None
        for line in manifest.splitlines():
            digest,path=line.split('  ',1)
            assert hashlib.sha256(bundle.read(NAME+'/'+path)).hexdigest()==digest
        for required in ('RUN_COMPARISON.m','RUN_V16_COMPARISON.m','RUN_V16_BOUNDS.m',
                         'matlab/leo_v16_parallel_sb.m','matlab/leo_v14_trust_path.m','matlab/leo_v15_certificate.m'):
            assert NAME+'/'+required in bundle.namelist()
        assert not any(Path(path).name.startswith(('RUN_V12','RUN_V13','RUN_V14','RUN_V15')) for path in bundle.namelist())
    print(f'PASS: {archive.name}: {count} required MATLAB sources, {len(sources)} total files, {archive.stat().st_size} bytes; hashes verified; no results or historical bundles.')


if __name__=='__main__':
    build()
