function result = leo_v8_ballistic_sb(ising,options,seeds,budget)
%LEO_BALLISTIC_SB 多轨迹 ballistic simulated bifurcation，无额外工具箱。
% 接口标注：
% 输入：ising：J/h；options：轨迹/积分参数；seeds：位种子；budget：软时间上限。
% 输出：result：每轨迹最佳位/能量、实际积分步、尺度、超时状态及检查点能量 history。
% 无量纲 a0=1；线性泵浦 0->1；辛 Euler；|position|>1 时非弹性壁。
% J 和 h 使用同一个正数归一化，保持能量相对尺度和符号。
% 返回每条轨迹检查点上最小离散能量，属于启发式结果。
if nargin<3, seeds = zeros(ising.nBits,0); end
if nargin<4, budget = []; end
n = ising.nBits; R = options.sbTrajectories;
assert(size(seeds,1)==n && all(seeds(:)==0 | seeds(:)==1));
position = 0.05*(2*rand(n,R)-1);
momentum = 0.05*(2*rand(n,R)-1);
nSeeds = min(size(seeds,2),R);
if nSeeds>0
    position(:,1:nSeeds) = (2*double(seeds(:,1:nSeeds))-1).* ...
        (0.05+0.02*rand(n,nSeeds));
end
spin = ones(n,R); spin(position<0) = -1;
bestSpin = spin;
bestEnergy = discrete_energy(ising,spin);
history.step = 0;
history.minimum = min(bestEnergy); history.median = median(bestEnergy); history.maximum = max(bestEnergy);
scale = max([sum(abs(ising.J),2)+abs(ising.h);realmin]);
J = ising.J/scale; h = ising.h/scale;
completedSteps = 0;
for k = 1:options.sbSteps
    if mod(k-1,options.sbCheckpoint)==0 && leo_budget_expired(budget), break; end
    pump = k/options.sbSteps;
    force = (pump-1)*position-options.sbCoupling*bsxfun(@plus,J*position,h);
    momentum = momentum+options.sbTimeStep*force;
    position = position+options.sbTimeStep*momentum;
    wall = abs(position)>1;
    position(wall) = sign(position(wall)); momentum(wall) = 0;
    completedSteps = k;
    if mod(k,options.sbCheckpoint)==0 || k==options.sbSteps
        spin = ones(n,R); spin(position<0) = -1;
        energy = discrete_energy(ising,spin);
        improve = energy<bestEnergy;
        bestSpin(:,improve) = spin(:,improve); bestEnergy(improve) = energy(improve);
        history.step(end+1) = k;
        history.minimum(end+1) = min(bestEnergy);
        history.median(end+1) = median(bestEnergy);
        history.maximum(end+1) = max(bestEnergy);
    end
end
result.bits = (bestSpin+1)/2;
result.energy = bestEnergy;
result.steps = completedSteps;
result.stoppedByTime = completedSteps<options.sbSteps;
result.energyScale = scale;
result.history = history;           % 同一个 Ising 问题，修复前离散历史最好能量
result.trajectories = R;
result.optimal = false;
end

function energy = discrete_energy(ising,spin)
energy = ising.constant+ising.h.'*spin+sum(spin.*(ising.J*spin),1)/2;
end
