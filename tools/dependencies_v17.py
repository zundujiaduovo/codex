"""Conservative MATLAB dependency closure for the single V17 distribution.

Tokens include function handles, dynamic installation names and script calls.
Only actual calls/handles are checked for missing custom functions.
"""
from pathlib import Path
import re

ROOT=Path(__file__).resolve().parents[1]
ROOT_SCRIPTS={'RUN_COMPARISON','RUN_V17_COMPARISON','RUN_V17_ALL','RUN_V17_BOUNDS',
              'RUN_V17_CONTROLS','SHOW_V17_RESULTS','TEST_V17','V17_SETTINGS',
              'V17_BOUND_SETTINGS','CHECK_V17_INSTALLATION'}


def code_without_comments(source):
    """Keep MATLAB strings/transpose while removing line comments."""
    output=[]; quoted=None; i=0
    while i<len(source):
        ch=source[i]
        if quoted:
            output.append(ch)
            if ch==quoted:
                if i+1<len(source) and source[i+1]==quoted:
                    output.append(source[i+1]); i+=1
                else: quoted=None
        elif ch=='%':
            end=source.find('\n',i)
            if end<0: break
            output.append('\n'); i=end
        else:
            output.append(ch)
            if ch=='"': quoted=ch
            elif ch=="'" and (i==0 or source[i-1].isspace() or source[i-1] in '=([{,;:+-*/~<>|&'):
                quoted=ch
        i+=1
    return ''.join(output)


def closure(root=ROOT):
    files=list(root.glob('*.m'))+list((root/'matlab').glob('*.m'))
    mapping={p.stem:p for p in files}
    assert ROOT_SCRIPTS<=mapping.keys()
    keep=set(); queue=[mapping[name] for name in sorted(ROOT_SCRIPTS)]
    while queue:
        path=queue.pop()
        if path in keep: continue
        keep.add(path)
        tokens=set(re.findall(r'\b[A-Za-z]\w*\b',code_without_comments(path.read_text(encoding='utf-8'))))
        queue.extend(mapping[token] for token in tokens & mapping.keys() if mapping[token] not in keep)
    return keep,set(files)-keep


def check(root=ROOT):
    keep,unused=closure(root)
    assert not unused, 'Unused MATLAB sources: '+', '.join(str(p.relative_to(root)) for p in sorted(unused))
    names={p.stem for p in keep}; missing=[]
    for p in keep:
        source=code_without_comments(p.read_text(encoding='utf-8'))
        calls=set(re.findall(r'\b((?:leo_|run_leo_)\w+)\s*\(',source))
        calls.update(re.findall(r'@((?:leo_|run_leo_)\w+)',source))
        # Local functions are resolved within their source file.
        locals_=set(re.findall(r'^function\s+(?:\[[^]]*\]|\w+)\s*=\s*(\w+)|^function\s+(\w+)\s*\(',source,re.M))
        local_names={name for pair in locals_ for name in pair if name}
        missing.extend((str(p.relative_to(root)),name) for name in calls-names-local_names)
    assert not missing, missing
    return len(keep)


if __name__=='__main__':
    keep,unused=closure()
    print(f'V17 dependency closure: {len(keep)} MATLAB files; {len(unused)} obsolete sources can be removed.')
    if unused: print('\n'.join(str(p.relative_to(ROOT)) for p in sorted(unused)))
    else: print('PASS:',check(),'MATLAB sources, no missing custom calls.')
