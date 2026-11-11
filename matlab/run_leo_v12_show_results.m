function [figures,files] = run_leo_v12_show_results(directory,releaseTag)
%RUN_LEO_V12_SHOW_RESULTS 打开已保存的V12两阶段六联图；只读结果，不执行优化。
% 优先可编辑FIG，其次PNG；图文件缺失时按现有JSON重新导出后打开。
if nargin<1, directory=fullfile('results','v12_uncapped_lexicographic'); end
if nargin<2, releaseTag='V12'; end
release=leo_lexicographic_release(releaseTag); prefix=release.prefix;
assert(exist(directory,'dir')==7,['Result directory not found: ',directory]);
names={[prefix,'_uncapped_lexicographic']};
specNames={[prefix,'_specs.json']};
if exist(fullfile(directory,[prefix,'_diagnostic_specs.json']),'file')==2
    names=[names,{[prefix,'_iteration_convergence'],[prefix,'_workload_quality']}];
    specNames=[specNames,{[prefix,'_diagnostic_specs.json'],[prefix,'_diagnostic_specs.json']}];
end
figureDirectories=repmat({directory},size(names));
if strcmp(release.tag,'V13') && exist(fullfile(directory,'candidate_audit','candidate_specs.json'),'file')==2
    names{end+1}='v13_candidate_diagnosis'; specNames{end+1}='candidate_specs.json';
    figureDirectories{end+1}=fullfile(directory,'candidate_audit');
end
figures={}; files={};
for j=1:numel(names)
    currentDirectory=figureDirectories{j};
    figPath=locate(currentDirectory,[names{j},'.fig']);
    pngPath=locate(currentDirectory,[names{j},'.png']);
    if isempty(figPath) && isempty(pngPath)
        specPath=fullfile(currentDirectory,specNames{j});
        if exist(specPath,'file')==2
            try
                spec=jsondecode(fileread(specPath));
                spec=spec(strcmp({spec.name},names{j})); assert(isscalar(spec),'Unexpected figure specification.');
                leo_render_plot_specs(spec,currentDirectory);
            catch err
                warning('leo:v12FigureRedraw','Cannot redraw %s: %s',names{j},err.message);
            end
            figPath=locate(currentDirectory,[names{j},'.fig']);
            pngPath=locate(currentDirectory,[names{j},'.png']);
        end
    end
    handle=[]; opened='';
    if ~isempty(figPath)
        try
            handle=openfig(figPath,'new','visible'); opened=figPath;
        catch err
            warning('leo:v12FigureOpen','Cannot open %s: %s',figPath,err.message);
        end
    end
    if isempty(handle) && ~isempty(pngPath)
        try
            pixels=imread(pngPath);
            handle=figure('Visible','on','Color','w','Name',names{j},'NumberTitle','off');
            image(pixels); axis image off; opened=pngPath;
        catch err
            if ~isempty(handle) && ishghandle(handle), close(handle); end
            handle=[];
            warning('leo:v12FigureOpen','Cannot display %s: %s',pngPath,err.message);
        end
    end
    if isempty(handle)
        warning('leo:v12FigureUnavailable','No result window opened for %s. Check saved FIG/PNG/JSON files in %s.',names{j},directory);
    else
        drawnow;
        figures{end+1}=handle; files{end+1}=opened; %#ok<AGROW>
        fprintf('%s result figure opened: %s\n',release.tag,opened);
    end
end
end
function path=locate(directory,name)
path='';
for folder={directory,fullfile(directory,'figures')}
    candidate=fullfile(folder{1},name);
    if exist(candidate,'file')==2, path=candidate; return; end
end
end
