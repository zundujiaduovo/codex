function result = leo_call_milp(model,seconds)
%LEO_CALL_MILP MATLAB intlinprog / Octave GLPK 适配，不掩盖求解器缺失或超时。
% 输入：leo_form_proxy_milp 输出、剩余秒数；输出变量、状态、最优性、called 与实际报告的 nodes。
result.z = []; result.objective = NaN; result.optimal = false;
result.status = 'unavailable'; result.backend = '';
result.called = false; result.nodes = NaN;
if seconds<=0, result.status = 'time_limit'; return; end
if exist('intlinprog','file')~=0
    result.backend = 'intlinprog';
    result.called = true;
    opts = optimoptions('intlinprog','Display','off','MaxTime',seconds);
    [z,f,flag,out] = intlinprog(model.f,model.intcon,model.A,model.b,[],[],model.lb,model.ub,opts);
    result.optimal = flag==1; result.status = sprintf('intlinprog_exit_%d',flag);
    result.message = out.message;
    if isfield(out,'numnodes'), result.nodes = out.numnodes; end
elseif exist('glpk','file')~=0
    result.backend = 'glpk';
    result.called = true;
    types = repmat('C',numel(model.f),1); types(model.intcon) = 'I';
    param.msglev = 0; param.tmlim = max(1,min(2^31-1,floor(1000*seconds)));
    [z,f,err,extra] = glpk(model.f,model.A,model.b,model.lb,model.ub, ...
        repmat('U',numel(model.b),1),types,1,param);
    result.optimal = err==0 && isfield(extra,'status') && extra.status==5;
    result.status = sprintf('glpk_error_%d',err);
    if isfield(extra,'status'), result.status = sprintf('%s_status_%d',result.status,extra.status); end
else
    return;
end
if ~isempty(z) && all(isfinite(z)) && all(abs(z(model.intcon)-round(z(model.intcon)))<1e-6) && ...
        all(z>=model.lb-1e-7 & z<=model.ub+1e-7) && all(model.A*z<=model.b+1e-7)
    result.z = z; result.objective = f;
else
    result.optimal = false;
end
end
