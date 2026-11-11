function [analysis,files] = run_leo_v12_diagnostics(source,directory,render)
%RUN_LEO_V12_DIAGNOSTICS 从已有MAT重画原生迭代/工作量，无需重新搜索或重算证书。
if nargin<1, source=fullfile('results','v12_uncapped_lexicographic'); end
if nargin<2 || isempty(directory)
    if ischar(source) && exist(source,'dir')==7, directory=source;
    elseif ischar(source), directory=fileparts(source);
    else, directory=fullfile('results','v12_diagnostics'); end
end
if nargin<3, render=true; end
report=leo_v12_load_report(source); if ~exist(directory,'dir'), mkdir(directory); end
analysis=leo_v12_diagnostic_data(report);
leo_write_struct_csv(fullfile(directory,'iteration_convergence.csv'),analysis.iterations);
leo_write_struct_csv(fullfile(directory,'workload_by_phase.csv'),analysis.phases);
leo_write_struct_csv(fullfile(directory,'workload_summary.csv'),analysis.workload);
leo_write_struct_csv(fullfile(directory,'fairness_targets.csv'),analysis.targets);
specs=leo_build_v12_diagnostic_specs(report,analysis);
fid=fopen(fullfile(directory,'v12_diagnostic_specs.json'),'w','n','UTF-8'); assert(fid>=0);
fprintf(fid,'%s',jsonencode(specs)); fclose(fid);
save(fullfile(directory,'diagnostics.mat'),'analysis','-v7');
files={}; if render, files=leo_render_plot_specs(specs,directory); end
fprintf('V12 diagnostics: %d native history points, %d completed runs; no optimization rerun. Missing old instrumentation remains NaN.\n',numel(analysis.iterations),numel(analysis.workload));
end
