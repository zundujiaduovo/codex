function [theory,fig] = run_leo_theory_from_saved(source,options,render)
%RUN_LEO_THEORY_FROM_SAVED 从原 benchmark.mat 计算全 QoS 理论上界，不重新运行算法。
if nargin<2, options = struct(); end
if nargin<3, render = true; end
if nargin<1 || isempty(source)
    [file,directory] = uigetfile('*.mat','Select benchmark.mat or raw_benchmark.mat');
    if isequal(file,0), theory = []; fig = []; return; end
    source = fullfile(directory,file);
end
if isempty(regexp(source,'^([A-Za-z]:[\\/]|[\\/])','once')), source = fullfile(pwd,source); end
loaded = load(source); assert(isfield(loaded,'report'),'MAT 文件中没有 report。');
report = loaded.report; directory = fullfile(fileparts(source),'certificate_v7');
if isfield(options,'outputDirectory')
    directory=options.outputDirectory; options=rmfield(options,'outputDirectory');
end
if isempty(regexp(directory,'^([A-Za-z]:[\\/]|[\\/])','once')), directory=fullfile(pwd,directory); end
previous=fullfile(directory,'theoretical_bound.mat');
if exist(previous,'file')
    saved=load(previous); if isfield(saved,'theory'), report.theory=saved.theory; end
end
theory = leo_theory_bound(report,options); report.theory = theory;
leo_export_theory_bound(report,directory);
fprintf('Full-QoS certified-service upper bound: %.6f Mbit/period\n',theory.upperBits/1e6);
fprintf('Best known feasible schedule: %.6f Mbit/period (%s)\n',theory.lowerBits/1e6,theory.bestMethod);
fprintf('Method: %s; %s\n',theory.kind,theory.pricingStatus);
if isfield(theory,'relativeGap') && isfinite(theory.relativeGap)
    fprintf('Certified remaining gap: %.6f%%; target %.6f%%; target met=%d; nodes=%d.\n', ...
        100*theory.relativeGap,100*theory.targetRelativeGap,theory.gapTargetMet,theory.nodesProcessed);
end
fprintf('Certificate output: %s\n',directory);
fprintf('Upper bound is conditional on full QoS and may not be attainable.\n');
fig = [];
if render, fig = leo_plot_theory_bound(report,directory); end
end
