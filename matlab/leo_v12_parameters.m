function p = leo_v12_parameters()
%LEO_V12_PARAMETERS 沿用V10/V11物理场景，目标改为未封顶公平优先的两阶段优化。
p=leo_paper_parameters();
p.problem.objectiveMode='lexicographic_max_min';
p.problem.requireFullQos=false;
end
