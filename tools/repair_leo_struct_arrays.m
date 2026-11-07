function repair_leo_struct_arrays(comparisonRoot)
%REPAIR_LEO_STRUCT_ARRAYS Patch legacy MATLAB struct appends, preserving other code.
% Run: repair_leo_struct_arrays(comparisonRoot)
% Makes a backup before editing. Safe to run again. Does not run simulations.
root = char(comparisonRoot);
sourceDir = fullfile(root,'matlab');
targets = {'leo_summarize_benchmark.m','leo_export_benchmark.m', ...
    'leo_collect_plot_data.m','leo_build_plot_specs.m'};
variables = {'summary','users|schedule', ...
    'data\.counts|data\.representatives|data\.serviceBounds|data\.events|data\.prices|data\.energy|rows', ...
    'p\.series|figures'};
before = cell(size(targets)); after = before; edits = zeros(size(targets));
for k = 1:numel(targets)
    path = fullfile(sourceDir,targets{k});
    assert(exist(path,'file')==2,['Missing required file: ',path]);
    before{k} = read_utf8(path);
    index = 'end\s*\+\s*1';
    if k==1, index = '(?:j|end\s*\+\s*1)'; end
    pattern = ['\<(',variables{k},')\s*\(\s*',index, ...
        '\s*,\s*1\s*\)\s*=\s*([A-Za-z]\w*)\s*;'];
    edits(k) = numel(regexp(before{k},pattern,'match'));
    after{k} = regexprep(before{k},pattern,'$1 = leo_append_struct($1,$2);');
end
helperPath = fullfile(sourceDir,'leo_append_struct.m');
createHelper = exist(helperPath,'file')~=2;
helper = sprintf(['function rows = leo_append_struct(rows,item)\n', ...
    '%% Append a scalar struct without assigning into a fieldless empty array.\n', ...
    'assert(isstruct(rows) && isstruct(item) && isscalar(item));\n', ...
    'if isempty(rows)\n    rows = item;\nelse\n    rows(end+1,1) = item;\nend\nend\n']);
if any(edits) || createHelper
    backup = [tempname(root),'_struct_fix_backup'];
    mkdir(backup);
    % Complete all backups before writing any source file.
    for k = find(edits)
        [ok,msg] = copyfile(fullfile(sourceDir,targets{k}),fullfile(backup,targets{k}));
        assert(ok,msg);
    end
    try
        if createHelper, write_utf8(helperPath,helper); end
        for k = find(edits), write_utf8(fullfile(sourceDir,targets{k}),after{k}); end
    catch err
        for k = find(edits)
            copyfile(fullfile(backup,targets{k}),fullfile(sourceDir,targets{k}),'f');
        end
        if createHelper && exist(helperPath,'file')==2, delete(helperPath); end
        rethrow(err);
    end
    fprintf('Backup: %s\n',backup);
else
    fprintf('No legacy append statements found; no files changed.\n');
end
clear leo_append_struct leo_summarize_benchmark leo_export_benchmark
clear leo_collect_plot_data leo_build_plot_specs
addpath(sourceDir,'-begin'); rehash;
% Exercise first append, later appends and preservation of record contents.
sample = struct('name','first','value',NaN);
rows = leo_append_struct(struct([]),sample);
second = struct('name','second','value',7);
rows = leo_append_struct(rows,second);
assert(isequal(size(rows),[2,1]) && isequaln(rows(1),sample) && isequal(rows(2),second));
for k = 1:numel(targets), fprintf('%s: %d replacements\n',targets{k},edits(k)); end
fprintf('Struct append smoke check passed. Resolved export: %s\n',which('leo_export_benchmark'));
end

function text = read_utf8(path)
fid = fopen(path,'rb'); assert(fid>=0,['Cannot read: ',path]);
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
text = native2unicode(fread(fid,Inf,'*uint8').','UTF-8');
end

function write_utf8(path,text)
bytes = unicode2native(text,'UTF-8');
fid = fopen(path,'wb'); assert(fid>=0,['Cannot write: ',path]);
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
written = fwrite(fid,bytes,'uint8'); assert(written==numel(bytes),['Incomplete write: ',path]);
end
