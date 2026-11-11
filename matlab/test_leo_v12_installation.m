function test_leo_v12_installation()
%TEST_LEO_V12_INSTALLATION 缺依赖/当前目录遮蔽先报清楚，结果文件不改动。
projectRoot=fileparts(fileparts(mfilename('fullpath')));
oldPath=path; oldDirectory=pwd; directory=tempname; mkdir(directory);
cleanup=onCleanup(@() finish(directory,oldPath,oldDirectory)); %#ok<NASGU>
addpath(projectRoot,'-begin'); addpath(fullfile(projectRoot,'matlab'),'-begin');
if any(strcmp(strsplit(path,pathsep),'matlab')), rmpath('matlab'); end
info=CHECK_V12_INSTALLATION(projectRoot); assert(numel(info.requiredFunctions)>=10);
mkdir(fullfile(directory,'matlab')); mkdir(fullfile(directory,'results'));
marker=fullfile(directory,'results','keep.txt'); write(marker,'existing search results');
for name=info.requiredFunctions
    if strcmp(name{1},'run_leo_v12_diagnostics'), continue; end
    copyfile(fullfile(projectRoot,'matlab',[name{1},'.m']),fullfile(directory,'matlab',[name{1},'.m']));
end
rejected=false;
try, CHECK_V12_INSTALLATION(directory);
catch err
    rejected=strcmp(err.identifier,'leo:v12IncompleteInstallation') && ~isempty(strfind(err.message,'run_leo_v12_diagnostics.m'));
end
assert(rejected && strcmp(fileread(marker),'existing search results'));
shadow=fullfile(directory,'shadow'); mkdir(shadow);
write(fullfile(shadow,'run_leo_v12_diagnostics.m'),sprintf('function out=run_leo_v12_diagnostics(varargin)\nout=[];\nend\n'));
cd(shadow); clear run_leo_v12_diagnostics; rejected=false;
try, CHECK_V12_INSTALLATION(projectRoot);
catch err, rejected=strcmp(err.identifier,'leo:v12PathShadow') && ~isempty(strfind(err.message,shadow)); end
assert(rejected);
cd(oldDirectory); clear run_leo_v12_diagnostics;
CHECK_V12_INSTALLATION(projectRoot);
assert(strcmp(fileread(marker),'existing search results'));
fprintf('PASS: V12 complete installation, missing diagnostics, current-folder shadowing, clear recovery messages and untouched existing results.\n');
end
function write(path,text)
fid=fopen(path,'w'); assert(fid>=0); fprintf(fid,'%s',text); fclose(fid);
end
function finish(directory,oldPath,oldDirectory)
cd(oldDirectory); path(oldPath); clear run_leo_v12_diagnostics;
if exist(directory,'dir')==7, rmdir(directory,'s'); end
end
