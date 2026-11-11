function [rows,files]=run_leo_v13_proxy_ablations(root,render)
% 每个配置同场景/同搜索种子；完整运行五方法，已有相同协议配对自动复用。
if nargin<1, root=pwd; end
if nargin<2, render=true; end
profiles={'baseline','iterations','refresh','candidates','combined'};
rows=struct([]); files={};
for j=1:numel(profiles)
    [o,folder]=V13_SETTINGS(profiles{j}); directory=fullfile(root,'results',folder);
    fprintf('\nV13 ABLATION %d/%d: %s\n',j,numel(profiles),profiles{j});
    [report,extra]=run_leo_v13_comparison(directory,o,render); files=[files,extra]; %#ok<AGROW>
    for k=1:numel(report.records)
        r=report.records(k);
        row=struct('profile',profiles{j},'method',leo_method_name(r.method),'seed',r.seed,'status',r.status, ...
            'stage1Fairness',r.stage1Fairness,'finalFairness',r.fairness,'totalBits',r.totalBits, ...
            'seconds',r.endToEndSeconds,'fairnessDeltaFromBaseline',NaN);
        at=[];
        if ~isempty(rows)
            at=find(strcmp({rows.profile},'baseline') & strcmp({rows.method},row.method) & [rows.seed]==row.seed,1);
        end
        if j==1, row.fairnessDeltaFromBaseline=0;
        elseif ~isempty(at), row.fairnessDeltaFromBaseline=row.stage1Fairness-rows(at).stage1Fairness; end
        rows=leo_append_struct(rows,row);
    end
end
directory=fullfile(root,'results','v13_proxy_ablation_summary'); if ~exist(directory,'dir'), mkdir(directory); end
leo_write_struct_csv(fullfile(directory,'ablation_summary.csv'),rows);
save(fullfile(directory,'ablation_summary.mat'),'rows','profiles','-v7');
spec=make_spec(rows,profiles);
fid=fopen(fullfile(directory,'ablation_specs.json'),'w','n','UTF-8'); assert(fid>=0);
fprintf(fid,'%s',jsonencode(spec)); fclose(fid);
if render, files=[files,leo_render_plot_specs(spec,directory)]; end
fprintf('V13 ablation summary: %s\n',directory);
end
function spec=make_spec(rows,profiles)
titles={'Stage-1 original fairness','Final total service at each attained floor','Actual end-to-end runtime'};
units={'min_i G_i/q_i','Mbit/period','Seconds'}; fields={'stage1Fairness','totalBits','seconds'};
methods={'Tabu','SB','Local','Proxy+Tabu','Greedy'};
for n=1:3
    p(n)=struct('kind','categorical_line','title',titles{n},'xlabel','Configuration','ylabel',units{n}, ...
        'labels',{profiles},'series',struct([]),'z',[],'zShape',[0,0],'clim',[],'xlabels',{{}},'ylabels',{{}}, ...
        'ylim',[],'reference',[],'referenceLabel','','note','Single requested seed. Native iterations and total work differ; throughput floors may differ.'); %#ok<AGROW>
    seed=rows(1).seed;
    for k=1:numel(methods)
        values=NaN(1,numel(profiles));
        for j=1:numel(profiles)
            at=find(strcmp({rows.profile},profiles{j}) & strcmp({rows.method},methods{k}) & [rows.seed]==seed,1);
            if ~isempty(at) && strcmp(rows(at).status,'completed'), values(j)=rows(at).(fields{n}); end
        end
        if n==2, values=values/1e6; end
        p(n).series=leo_append_struct(p(n).series,struct('name',methods{k},'x',1:numel(profiles),'y',values,'low',[],'high',[]));
    end
end
spec=struct('name','v13_proxy_ablation_comparison','title','V13 proxy refinement ablations | same physical model', ...
    'rows',1,'cols',3,'panels',p);
end
