function [problem,report]=leo_test_problem()
p=leo_default_parameters(); p.problem.objectiveMode='lexicographic_max_min'; p.problem.requireFullQos=false;
p.statistics.serviceModel='slot_union'; p.system.K=4; p.system.maxStreams=2;
p.system.bandwidthHz=1e6; p.system.qosTargetBits=[.3;.4;.5;.6]*1e6;
p.time.nSlots=4; p.time.blockSlots=2; p.time.slotDurationS=.5;
p.time.baseOverheadS=0; p.time.configOverheadS=0; p=leo_validate_parameters(p);
resources=leo_build_resources(p); b.available=true(4,2); b.index=repmat([1;1;2;3],1,2);
design.signalW=[1,.2,3,1;4,.8,2,.4;.5,2,.6,3;1,2,3,4];
design.noiseW=repmat([1,2,1.5,3],4,1); design.beamPowerW=zeros(4,3,4); design.serviceModel='slot_union';
design.serviceScale=[.8;.9;.85;.95]; design.serviceMarginBits=[.01;.02;.01;.03]*1e6;
for t=1:4, design.beamPowerW(:,:,t)=[2,5,3;2,1,4;5,1,2;3,4,5]*(.1+.01*t); end
problem=leo_form_problem(p,resources,b,design);
report=struct('problemData',problem.data,'parameters',p, ...
    'records',struct('method','witness','seed',1,'status','completed'), ...
    'solutions',{{struct('x',false(4,2))}});
end
