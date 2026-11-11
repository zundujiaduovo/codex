function [figures,files] = run_leo_v12_show_results(directory)
%RUN_LEO_V12_SHOW_RESULTS 打开已保存的V12两阶段六联图；只读结果，不执行优化。
% 优先可编辑FIG，其次PNG；图文件缺失时按现有JSON重新导出后打开。
if nargin<1, directory=fullfile('results','v12_uncapped_lexicographic'); end
assert(exist(directory,'dir')==7,['Result directory not found: ',directory]);
names={'v12_uncapped_lexicographic'};
specNames={'v12_specs.json'};
figures={}; files={};
for j=1:numel(names)
    figPath=locate(directory,[names{j},'.fig']);
    pngPath=locate(directory,[names{j},'.png']);
    if isempty(figPath) && isempty(pngPath)
        specPath=fullfile(directory,specNames{j});
        if exist(specPath,'file')==2
            try
                spec=jsondecode(fileread(specPath));
                assert(isscalar(spec) && strcmp(spec.name,names{j}),'Unexpected figure specification.');
                leo_render_plot_specs(spec,directory);
            catch err
                warning('leo:v12FigureRedraw','Cannot redraw %s: %s',names{j},err.message);
            end
            figPath=locate(directory,[names{j},'.fig']);
            pngPath=locate(directory,[names{j},'.png']);
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
        fprintf('V12 result figure opened: %s\n',opened);
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
