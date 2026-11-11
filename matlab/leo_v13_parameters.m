function p = leo_v13_parameters()
%LEO_V13_PARAMETERS 基于V12：64用户、64固定波束，最多16人并发（1/4波束准入）。
p=leo_v12_parameters();
p.system.K=64;
p.array.nBeams=64;
p.array.gridOversampling=4; % 原2倍网格在26度扫描域内不足64个合法码字
p.system.maxStreams=16;
p.system.nRF=16;
% 每流功率保持10 W；16流满载需160 W，不能沿用V12的80 W上限。
p.system.maxPowerW=p.system.maxStreams*p.system.streamPowerW;
p.users.layout='reference64';
p.problem.referenceBits=[];
end
