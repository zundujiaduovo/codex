function test_leo_v11_show_results()
%TEST_LEO_V11_SHOW_RESULTS 无GUI检查：已有图可见打开、缺图按JSON重画、缺失不伪造。
directory=tempname; mkdir(directory); mocks=fullfile(directory,'mocks'); mkdir(mocks);
cleanup=onCleanup(@() finish(directory,mocks)); %#ok<NASGU>
write_text(fullfile(mocks,'openfig.m'),sprintf(['function handle=openfig(varargin)\n', ...
    'global v11ViewCalls; v11ViewCalls{end+1}=varargin; handle=numel(v11ViewCalls);\nend\n']));
write_text(fullfile(mocks,'leo_render_plot_specs.m'),sprintf(['function files=leo_render_plot_specs(spec,directory)\n', ...
    'global v11RedrawCalls; v11RedrawCalls=v11RedrawCalls+1;\n', ...
    'path=fullfile(directory,[spec.name,''.fig'']); fid=fopen(path,''w''); fclose(fid); files={path};\nend\n']));
addpath(mocks,'-begin'); clear openfig leo_render_plot_specs;
global v11ViewCalls v11RedrawCalls;
v11ViewCalls={}; v11RedrawCalls=0;
paired=fullfile(directory,'v11_based_on_v10_paired.fig'); write_text(paired,'test fixture');
mkdir(fullfile(directory,'figures'));
inner=fullfile(directory,'figures','v11_based_on_v10_inner_control.fig'); write_text(inner,'test fixture');
[handles,files]=run_leo_v11_show_results(directory);
assert(numel(handles)==2 && isequal(files,{paired,inner}) && v11RedrawCalls==0);
for j=1:2
    assert(isequal(v11ViewCalls{j}(2:3),{'new','visible'}));
end
% 没有任何原始实验MAT仍能用已保存规格重画；已有FIG不能被重写。
delete(inner);
write_text(fullfile(directory,'v11_inner_specs.json'),jsonencode(struct('name','v11_based_on_v10_inner_control')));
[handles,files]=run_leo_v11_show_results(directory);
assert(numel(handles)==2 && v11RedrawCalls==1);
assert(strcmp(files{2},fullfile(directory,'v11_based_on_v10_inner_control.fig')));
assert(strcmp(fileread(paired),'test fixture'));
% 缺少某张图和规格时清楚报告，仅打开实际存在的一张。
delete(fullfile(directory,'v11_based_on_v10_inner_control.fig'));
delete(fullfile(directory,'v11_inner_specs.json'));
previous=warning('query','leo:v11FigureUnavailable');
restore=onCleanup(@() warning(previous.state,'leo:v11FigureUnavailable')); %#ok<NASGU>
warning('off','leo:v11FigureUnavailable');
[handles,files]=run_leo_v11_show_results(directory);
assert(numel(handles)==1 && numel(files)==1 && v11RedrawCalls==1);
fprintf('PASS: V11 existing figures open visibly, saved-spec redraw, subdirectory discovery, missing figures and no experiment rerun.\n');
end
function write_text(path,contents)
fid=fopen(path,'w'); assert(fid>=0); fprintf(fid,'%s',contents); fclose(fid);
end
function finish(directory,mocks)
if any(strcmp(strsplit(path,pathsep),mocks)), rmpath(mocks); end
clear openfig leo_render_plot_specs;
clear global v11ViewCalls v11RedrawCalls;
if exist(directory,'dir')==7, rmdir(directory,'s'); end
end
