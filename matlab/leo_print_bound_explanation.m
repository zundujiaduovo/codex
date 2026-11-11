function leo_print_bound_explanation(report)
%LEO_PRINT_BOUND_EXPLANATION 窗口说明原模型上界推导；有证书时同时打印数值。
d=report.problemData; p=report.parameters; [alpha,c]=leo_service_adjustment(d);
fprintf('\n上界计算：用人数条件的最小干扰获得每块服务上界，再对合法用户组做配置LP松弛，以全域定价的对偶值作为公平上界。\n');
fprintf('本次按%d阵元原模型重算所有系数；结束后打印粗界、配置LP界与已找到的可行值。\n',p.array.nElements);
fprintf('\n=== ORIGINAL-MODEL UPPER BOUNDS | Na=%d (%dx%d), K=%d, NB=%d, L=%d ===\n', ...
    p.array.nElements,p.array.nX,p.array.nY,d.shape(1),p.array.nBeams,d.maxStreams);
fprintf('G_i=max(0,A_i-c_i), A_i=sum_m f_i,m; q_i is cumulative demand; s=min_i G_i/q_i (uncapped).\n');
fprintf('q_i range [%.6g, %.6g] Mbit; alpha_i range [%.6g, %.6g]; c_i range [%.6g, %.6g] Mbit.\n', ...
    min(d.qosTargetBits)/1e6,max(d.qosTargetBits)/1e6,min(alpha),max(alpha),min(c)/1e6,max(c)/1e6);
fprintf('1) For group size n<=L, Imin_i,t(n) sums the n-1 SMALLEST interference powers from DISTINCT other available beams.\n');
fprintf('   u_i,m,n=alpha_i * sum_{t in m} dt_t*B*log2(1+S_i,t/(N_i,t+Imin_i,t(n))).\n');
fprintf('   Actual f_i,m<=u_i,m,n: real interferers cannot have less power than these n-1 minima.\n');
fprintf('2) Legal groups retain <=L users and <=1 user per beam. Let a_i,m,g=1{i in g}*u_i,m,|g|/q_i.\n');
fprintf('   Configuration LP: max s, sum_m,g a_i,m,g*p_m,g >= s+c_i/q_i; sum_g p_m,g=1; p>=0.\n');
fprintf('   Group mixtures and optimistic per-user rates enlarge the ORIGINAL feasible set, giving an upper bound.\n');
fprintf('3) For ANY lambda>=0, h_m(lambda)=max_legal_g sum_i lambda_i*a_i,m,g.\n');
fprintf('   U(lambda)=max(0, Smax*[1-sum_i lambda_i]_+ + sum_m h_m(lambda) - sum_i lambda_i*c_i/q_i).\n');
fprintf('   s*<=min(Smax,U(lambda)); Smax is the coarse no-interference user bottleneck.\n');
fprintf('   Pricing h_m is exact for this RELAXATION: for each n=1..L, take each beam best user, then the n best beams.\n');
fprintf('   Column generation improves lambda; ONLY the full-domain dual value is used as the upper bound.\n');
fprintf('4) At positive fixed floor s0, throughput bound: V*<=sum_m H_m(w)-sum_i c_i-s0*sum_i mu_i*q_i,\n');
fprintf('   w_i=1+mu_i, mu>=0; H_m(w)=max_legal_g sum_i w_i*1{i in g}*u_i,m,|g|.\n');
fprintf('   Each method has its own stated s0. At zero floor, the code uses a safe bound respecting clipping at zero.\n');
fprintf('All S/N/interference/u coefficients are rebuilt from this array/channel. An upper bound may remain loose; it is not an attained optimum.\n');
if isfield(report,'fairnessCertificate')
    cert=report.fairnessCertificate;
    if isfield(cert,'cardinalityRelaxation')
        b=cert.cardinalityRelaxation;
        fprintf('COMPUTED: Smax=%.12g; uniform-lambda bound=%.12g; configuration-LP dual=%.12g; LP status=%s.\n', ...
            cert.coarseUpper,b.uniformUpper,b.upper,b.status);
    end
    fprintf('FINAL ORIGINAL fairness interval: [%.12g, %.12g]; relative remaining gap %.6g%%.\n', ...
        cert.lower,cert.upper,100*cert.relativeGap);
    for j=1:numel(report.conditionalBounds)
        b=report.conditionalBounds(j);
        fprintf('  %-12s s0=%.9g: V=%.6g Mbit; conditional upper=%.6g Mbit.\n', ...
            leo_method_name(b.method),b.fairnessFloor,b.methodTotalBits/1e6,b.conditionalUpperBits/1e6);
    end
end
fprintf('=== END UPPER-BOUND EXPLANATION ===\n\n');
end
