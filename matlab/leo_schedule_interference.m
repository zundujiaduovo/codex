function I = leo_schedule_interference(data,x)
%LEO_SCHEDULE_INTERFERENCE 合法完整日程的设计干扰；包含未选用户的反事实接收值。
% 接口标注：
% 输入：data：设计信道；x：K×M 合法二元日程。
% 输出：I：K×T 干扰功率 W，含未选用户的反事实接收干扰。
% 未选用户的这个值可能超过条件 x_i=1 的 Imax，不能直接当作合法切点。
leo_evaluate_service(data,x);        % 复用原始日程可行性校验
K = data.shape(1); T = numel(data.slotToResource);
I = zeros(K,T);
for t = 1:T
    if data.dataDurationS(t)<=0, continue; end
    m = data.slotToResource(t);
    ids = find(data.available(:,m));
    C = zeros(K,K);
    C(:,ids) = data.design.beamPowerW(:,data.beamIndex(ids,m),t);
    C(1:K+1:end) = 0;
    I(:,t) = C*double(x(:,m));
end
end
