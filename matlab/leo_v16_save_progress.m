function leo_v16_save_progress(o,phase,x,service,history,convergence,iteration)
% Recoverable feasible snapshot, not a claim of exact interrupted-chain resume.
if ~isfield(o,'progressDirectory') || isempty(o.progressDirectory) || mod(iteration,25)~=0, return; end
directory=o.progressDirectory; if ~exist(directory,'dir'), mkdir(directory); end
columns=iteration; if isfield(history,'iteration'), columns=numel(history.iteration); end
for name=fieldnames(history).'
    field=name{1};
    if strcmp(field,'priceX'), history.(field)=history.(field)(:,:,1:columns);
    else, history.(field)=history.(field)(:,1:min(columns,size(history.(field),2))); end
end
progress=struct('phase',phase,'iteration',iteration,'x',x,'service',service, ...
    'history',history,'convergence',convergence,'complete',false);
temporary=[tempname(directory),'.mat']; save(temporary,'progress','-v7');
[ok,message]=movefile(temporary,fullfile(directory,[phase,'.mat']),'f'); assert(ok,message);
end
