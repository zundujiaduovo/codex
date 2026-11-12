function leo_v16_save_progress(o,phase,x,service,history,convergence,iteration)
% Recoverable feasible snapshot, not a claim of exact interrupted-chain resume.
if ~isfield(o,'progressDirectory') || isempty(o.progressDirectory) || mod(iteration,25)~=0, return; end
directory=o.progressDirectory; if ~exist(directory,'dir'), mkdir(directory); end
progress=struct('phase',phase,'iteration',iteration,'x',x,'service',service, ...
    'history',history,'convergence',convergence,'complete',false);
temporary=[tempname(directory),'.mat']; save(temporary,'progress','-v7');
[ok,message]=movefile(temporary,fullfile(directory,[phase,'.mat']),'f'); assert(ok,message);
end
