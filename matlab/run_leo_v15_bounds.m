function [report,files]=run_leo_v15_bounds(source,directory,settings,render)
% Apply independent certificates to saved searches, including existing V14 data.
if nargin<3, settings=V17_BOUND_SETTINGS(); end
if nargin<4, render=true; end
report=leo_v12_load_report(source); originalReport=report;
if ~exist(directory,'dir'), mkdir(directory); end
fairDirectory=fullfile(directory,'fairness');
certificate=leo_v15_certificate(report,fairDirectory,'fairness',0,settings.fairness);
report.fairnessCertificate=certificate; files=render_certificate(fairDirectory);
conditional=struct([]); floors=[]; bounds={};
for j=1:numel(report.records)
    r=report.records(j); if ~strcmp(r.status,'completed'), continue; end
    report.records(j).globalFairnessUpper=certificate.upper;
    report.records(j).fairnessGapAtLeast=max(0,certificate.lower-r.fairness);
    report.records(j).fairnessGapAtMost=max(0,certificate.upper-r.fairness);
    report.records(j).stage1CertificateConfirmed=certificate.upper-r.stage1Fairness<=max(certificate.options.absoluteGap,certificate.options.relativeGap*certificate.upper);
    if ~settings.conditionalThroughput, continue; end
    floorValue=r.stage1Fairness; assert(floorValue>0,'A positive stage-1 floor is needed for signed-service throughput certification.');
    at=find(floors==floorValue,1);
    if isempty(at)
        folder=['throughput_s_',strrep(strrep(sprintf('%.17g',floorValue),'.','p'),'-','m')];
        tDirectory=fullfile(directory,folder);
        t=leo_v15_certificate(report,tDirectory,'throughput',floorValue,settings.throughput);
        floors(end+1)=floorValue; bounds{end+1}=t; at=numel(floors);
        files=[files,render_certificate(tDirectory)]; %#ok<AGROW>
    end
    t=bounds{at}; report.records(j).conditionalThroughputUpperBits=t.upperBits;
    conditional=leo_append_struct(conditional,struct('method',r.method,'seed',r.seed,'fairnessFloor',floorValue, ...
        'methodTotalBits',r.totalBits,'conditionalLowerBits',t.lowerBits,'conditionalUpperBits',t.upperBits, ...
        'relativeIntervalGap',t.relativeGap,'pricingComplete',t.pricingComplete,'status',t.status, ...
        'scope','ORIGINAL sum(G) optimum at this EXACT stated floor; certificate computations are not method performance.'));
end
if settings.conditionalThroughput, report.conditionalBounds=conditional; end
report.sourceSearchRelease='saved_original_search';
if isfield(originalReport,'releaseTag'), report.sourceSearchRelease=originalReport.releaseTag; end
report.releaseTag='V17'; report.options.outputDirectory=directory;
save(fullfile(directory,'certified_benchmark.mat'),'report','-v7');
leo_write_struct_csv(fullfile(directory,'certified_runs.csv'),report.records);
if ~isempty(conditional), leo_write_struct_csv(fullfile(directory,'conditional_throughput_bounds.csv'),conditional); end
specs=leo_build_v12_specs(report,leo_v12_trace_data(report));
files=[files,leo_v14_save_specs(specs,directory,'v17_certified_comparison_specs',render)];
fprintf('Original certification saved to %s. Original benchmark search scores and timings were retained.\n',directory);

    function outputs=render_certificate(folder)
        a=load(fullfile(folder,'checkpoint.mat'),'state'); b=load(fullfile(folder,'certificate.mat'),'certificate');
        outputs=leo_v15_export_certificate(a.state,b.certificate,folder,render);
    end
end
