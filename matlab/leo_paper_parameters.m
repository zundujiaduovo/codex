function p = leo_paper_parameters()
%LEO_PAPER_PARAMETERS 参考 Zhao 等论文 Table I 的部分物理参数，并非论文复现。
% 原文上行、MRC、资源数约束；本模型仍为下行固定波束和周期保证 QoS。
% 原文未明确给出用户位置采样方式/随机种子，默认保留已存的固定 32 用户场景。
p = leo_default_parameters();
p.system.carrierHz = 4e9;             % 论文 Table I，4 GHz
p.channel.ricianKDb = 12;             % 论文 Table I，12 dB
p.channel.elementGainDbi = 6;         % 论文卫星天线增益；本模型用作单阵元增益
p.channel.receiveGainDbi = 1;         % 论文终端天线增益
p.channel.extraLossDb = 0;            % 论文链路预算公式未含固定附加损耗项
p.users.layout = 'reference32';
p.system.maxStreams = 7;              % 用户要求每块严格小于 8 人
p.problem.requireFullQos = true;
p.statistics.serviceModel = 'periodic_multilevel';
p.statistics.fadingLevels = 64;
p.statistics.referenceFadeGrid = [.25,.5,.75,1,1.5,2];
p.statistics.tiltGrid = [1,2.5,5,10,20,40];
% 600 km、8x8、半波长已经与论文相同；带宽、功率和 QoS 沿用本模型。
end
