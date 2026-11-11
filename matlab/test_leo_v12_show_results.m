function test_leo_v12_show_results()
%TEST_LEO_V12_SHOW_RESULTS 无GUI核对旧六联图与新增多规格迭代/工作量图的可见打开。
directory=tempname; mkdir(directory); mocks=fullfile(directory,'mocks'); mkdir(mocks);
cleanup=onCleanup(@() finish(directory,mocks)); %#ok<NASGU>
write(fullfile(mocks,'openfig.m'),sprintf(['function handle=openfig(varargin)\n', ...
    'global v12ViewCalls; v12ViewCalls{end+1}=varargin; handle=numel(v12ViewCalls);\nend\n']));
write(fullfile(mocks,'leo_render_plot_specs.m'),sprintf(['function files=leo_render_plot_specs(spec,directory)\n', ...
    'assert(isscalar(spec)); global v12RedrawCalls; v12RedrawCalls=v12RedrawCalls+1;\n', ...
    'path=fullfile(directory,[spec.name,''.fig'']); fid=fopen(path,''w''); fclose(fid); files={path};\nend\n']));
addpath(mocks,'-begin'); clear openfig leo_render_plot_specs;
global v12ViewCalls v12RedrawCalls; v12ViewCalls={}; v12RedrawCalls=0;
path=fullfile(directory,'v12_uncapped_lexicographic.fig'); write(path,'existing original figure');
[handles,files]=run_leo_v12_show_results(directory);
assert(numel(handles)==1 && numel(files)==1 && v12RedrawCalls==0);
specs=struct('name',{'v12_iteration_convergence','v12_workload_quality'});
write(fullfile(directory,'v12_diagnostic_specs.json'),jsonencode(specs));
[handles,files]=run_leo_v12_show_results(directory);
assert(numel(handles)==3 && numel(files)==3 && v12RedrawCalls==2);
assert(strcmp(fileread(path),'existing original figure'));
for j=1:numel(v12ViewCalls), assert(isequal(v12ViewCalls{j}(2:3),{'new','visible'})); end
run_leo_v12_show_results(directory); assert(v12RedrawCalls==2);
% V13复用查看器，按独立前缀读取规格并打开三张四方法图。
write(fullfile(directory,'v13_specs.json'),jsonencode(struct('name','v13_uncapped_lexicographic')));
specs=struct('name',{'v13_iteration_convergence','v13_workload_quality'});
write(fullfile(directory,'v13_diagnostic_specs.json'),jsonencode(specs));
[handles,files]=run_leo_v12_show_results(directory,'V13');
assert(numel(handles)==3 && numel(files)==3 && v12RedrawCalls==5);
fprintf('PASS: V12 legacy figure opening, array-spec redraw, three visible windows and no experiment rerun (mock GUI).\n');
end
function write(path,text)
fid=fopen(path,'w'); assert(fid>=0); fprintf(fid,'%s',text); fclose(fid);
end
function finish(directory,mocks)
if any(strcmp(strsplit(path,pathsep),mocks)), rmpath(mocks); end
clear openfig leo_render_plot_specs;
clear global v12ViewCalls v12RedrawCalls;
if exist(directory,'dir')==7, rmdir(directory,'s'); end
end
