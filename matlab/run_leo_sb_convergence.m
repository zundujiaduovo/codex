function [files,specs] = run_leo_sb_convergence(source,directory,render)
%RUN_LEO_SB_CONVERGENCE 读取现有benchmark/plot_data，为每个SB生成独立收敛图。
% 不重跑算法。支持report/plotData结构或MAT路径。render=false仅导出CSV/JSON。
if nargin<1 || isempty(source)
 [file,folder]=uigetfile('*.mat','Select benchmark.mat, raw_benchmark.mat or plot_data.mat');
 if isequal(file,0), files={}; specs=struct([]); return; end
 source=fullfile(folder,file);
end
if nargin<3, render=true; end
base=pwd;
if ischar(source) || (isstring(source) && isscalar(source))
 source=char(source);
 if isempty(regexp(source,'^([A-Za-z]:[\\/]|[\\/])','once')), source=fullfile(pwd,source); end
 base=fileparts(source); saved=load(source);
 if isfield(saved,'report'), source=saved.report;
 elseif isfield(saved,'plotData'), source=saved.plotData;
 else, error('leo:missingLogs','MAT file must contain report or plotData.'); end
end
if nargin<2 || isempty(directory), directory=fullfile(base,'sb_convergence'); end
if isempty(regexp(directory,'^([A-Za-z]:[\\/]|[\\/])','once')), directory=fullfile(pwd,directory); end
if isfield(source,'schemaVersion'), data=source; else, data=leo_collect_plot_data(source); end
specs=leo_build_sb_convergence_specs(data); files={};
if ~exist(directory,'dir'), mkdir(directory); end
methods=data.methods(ismember(data.methods,{'sb_v8_blockwise','local_v8_blockwise','price_sb','price_sb_blockwise','price_sb_adaptive', ...
 'price_sb_joint','price_sb_light','sb_zero','sb_minimax_fixed','sb_current_fixed','sb_reference_portfolio', ...
 'original_exchange','original_tabu','original_tabu_independent','price_local_blockwise','price_local_joint','price_local_adaptive'}));
rows=data.progress;
if ~isempty(rows), rows=rows(ismember({rows.method},methods) & [rows.seed]==data.representativeSeed); end
leo_write_struct_csv(fullfile(directory,'sb_convergence_time.csv'),rows);
rows=data.events;
if ~isempty(rows), rows=rows(ismember({rows.method},methods) & [rows.seed]==data.representativeSeed); end
leo_write_struct_csv(fullfile(directory,'sb_convergence_rounds.csv'),rows);
rows=data.energy;
if ~isempty(rows), rows=rows(ismember({rows.method},methods) & [rows.seed]==data.representativeSeed); end
leo_write_struct_csv(fullfile(directory,'sb_convergence_energy.csv'),rows);
fid=fopen(fullfile(directory,'sb_convergence_specs.json'),'w','n','UTF-8'); assert(fid>=0);
cleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s\n',jsonencode(specs));
if render && ~isempty(specs), files=leo_render_plot_specs(specs,directory); end
fprintf('SB convergence: %d figures, seed %.0f, output %s; no algorithm rerun.\n', ...
 numel(specs),data.representativeSeed,directory);
end
