function test_leo_v14_components()
% 小规模独立性质检查；不运行64用户性能实验。
c=leo_v14_coordination_options(); o=leo_method_options(struct('coordination',c));
data=struct('shape',[3,1],'qosTargetBits',ones(3,1),'referenceBits',3,'fairnessUpperLimit',20.537, ...
    'objectiveMode','lexicographic_max_min');
[weights,aux]=leo_price_weights(data,ones(3,1)/3,'fairness',0,o); assert(aux==0 && abs(sum(weights)-1)<1e-12);
lambda=ones(3,1)/3; state=struct();
for k=1:100
    [lambda,state]=leo_update_prices(lambda,[1;2;3],ones(3,1),0,1/k^.6,'fairness',o,state);
    assert(all(lambda>=0) && abs(sum(lambda)-1)<1e-12);
end
assert(lambda(1)>lambda(2) && lambda(2)>lambda(3));
lambda2=leo_update_prices(zeros(3,1),[1;2;3],ones(3,1),2,.1,'throughput',o);
assert(isequal(lambda2,[.1;0;0]));
% 旧式先走到终点再过滤会丢掉距离2的小步；可信域内路径必须保留。
q=struct('nUsers',6,'A',(6:-1:1).','B',zeros(6),'beamIndex',(1:6).','maxStreams',6);
center=false(6,1);
[near,path]=leo_v14_trust_path(q,center,[],2,6);
assert(nnz(near)==2 && size(path,2)==3 && all(sum(path,1)<=2));
assert(q.A.'*double(near)==11);
[~,bridge]=leo_v14_trust_path(q,center,true(6,1),2,6);
assert(size(bridge,2)>1 && all(sum(bridge,1)<=2));
for L=1:32
    q=struct('nUsers',L,'A',ones(L,1),'B',zeros(L),'beamIndex',(1:L).', ...
        'maxStreams',L,'capacityIncluded',true,'slackWeights',2.^(0:ceil(log2(L+1))-1).');
    q=leo_v14_encode_qubo(q,1.2); assert(sum(q.slackWeights)==L);
    for n=0:L
        x=false(L,1); x(1:n)=true; z=leo_encode_group_bits(q,x);
        assert(abs(q.constant+z.'*q.Qsym*z+n)<1e-10);
    end
end
[problem,start,banks]=fixture(); o.coordination=c;
budget=struct('timer',tic,'seconds',Inf,'iterationOnly',true);
for m=1:2
    x=start.x; x(:,m)=banks{m}.groups;
    assert(~leo_service_is_better(problem.evaluate(x),start.service,'fairness',0));
end
joint=leo_v14_joint_blocks(problem,start,banks,'fairness',0,o,budget);
assert(joint.accepted==1 && joint.service.fairness>start.service.fairness);
report=struct('problemData',problem.data);
bound=leo_v14_coupled_bound(report,'fairness',0);
assert(bound.upper>=joint.service.fairness-1e-7);
report.records=struct('method','witness','seed',1,'status','completed');
report.solutions={struct('x',joint.x,'stage1',struct('x',joint.x))};
floorBound=leo_v14_floor_bound(report,1.2,20); assert(floorBound.upperBits>=joint.service.totalBits-1e-6);
fprintf('PASS: V14 normalized prices, independent stage-2 multipliers, trust paths, bounded slack, compensating joint move and valid coupled/floor bounds.\n');
end
function [problem,start,banks]=fixture()
p=leo_default_parameters(); p.system.K=2; p.system.maxStreams=1;
p.system.bandwidthHz=1; p.system.qosTargetBits=1; p.problem.referenceBits=2;
p.problem.objectiveMode='lexicographic_max_min'; p.problem.requireFullQos=false;
p.time.nSlots=2; p.time.blockSlots=1; p.time.slotDurationS=1; p.time.baseOverheadS=0; p.time.configOverheadS=0;
p=leo_validate_parameters(p); r=leo_build_resources(p);
b.available=true(2,2); b.index=repmat((1:2).',1,2);
d=struct('signalW',[1,2^1.6-1;2^1.6-1,1],'noiseW',ones(2,2),'beamPowerW',zeros(2,2,2), ...
    'serviceModel','slot_union','serviceScale',ones(2,1),'serviceMarginBits',zeros(2,1));
problem=leo_form_problem(p,r,b,d); x=logical(eye(2)); start=struct('x',x,'service',problem.evaluate(x));
banks={struct('groups',logical([0;1]),'sources',{{'compensation'}}),struct('groups',logical([1;0]),'sources',{{'bottleneck'}})};
end
