function [model,fig] = run_leo_quickstart(outputDirectory)
%RUN_LEO_QUICKSTART 运行默认 32 用户调度并立即显示、保存结果图。
if nargin<1, outputDirectory = fullfile('results','quickstart'); end
p = leo_default_parameters(); p.method.enabled = true;
model = run_leo_sinr(p);
s = model.method.service; q = model.problem.data.qosTargetBits;
assert(model.problem.precheck.maxFlow==p.system.K, ...
    '默认场景存在不可服务用户；请检查是否使用了最新版参考用户文件。');
nominal = leo_evaluate_nominal_service(model.problem.data,model.method.x);
fig = figure('Color','w','Name','LEO 周期 QoS 结果','Position',[80,80,1100,690]);
subplot(2,2,1);
bar(s.demandRatio); hold on; plot([.5,p.system.K+.5],[1,1],'r--');
xlabel('User'); ylabel('Guaranteed service / demand'); title('Period QoS ratio'); grid on;
subplot(2,2,2);
bar([s.userBits,q]/1e6,'grouped');
xlabel('User'); ylabel('Mbit / period'); title('Guaranteed service and target');
legend({'Guaranteed','Target'},'Location','best'); grid on;
subplot(2,2,3);
bar(sum(model.method.x,2)); xlabel('User'); ylabel('Selected blocks');
title('Schedule allocation'); grid on;
subplot(2,2,4);
bar([s.totalBits,nominal.totalBits]/(1e6*model.problem.data.periodSeconds));
set(gca,'XTickLabel',{'Guaranteed','Z=1 reference'});
ylabel('Mbps'); title('Sum rate: guarantee vs reference'); grid on;
if ~exist(outputDirectory,'dir'), mkdir(outputDirectory); end
print(fig,fullfile(outputDirectory,'quickstart.png'),'-dpng','-r160');
fprintf('Guaranteed fairness %.4f; full-QoS users %d/%d; guaranteed sum %.3f Mbit/period.\n', ...
    s.fairness,nnz(s.demandRatio>=1),p.system.K,s.totalBits/1e6);
fprintf('Figure saved to %s\n',fullfile(outputDirectory,'quickstart.png'));
end
