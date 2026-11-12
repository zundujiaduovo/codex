function files=leo_v15_export_certificate(s,c,directory,render)
if nargin<4, render=false; end
row=struct('phase',s.phase,'floor',s.floor,'lower',c.lower,'upper',c.upper, ...
    'relativeGap',c.relativeGap,'targetGap',c.options.relativeGap,'gapTargetMet',c.gapTargetMet, ...
    'status',c.status,'rootConfigurationLPComplete',c.rootConfigurationLPComplete, ...
    'openScheduleNodes',c.openNodeCount,'scheduleNodesProcessed',c.nodesProcessed, ...
    'pricingNodesExpanded',c.pricingNodes,'pricingCalls',c.pricingCalls,'elapsedSeconds',c.elapsedSeconds, ...
    'units','fairness: ratio; throughput: Mbit per period');
leo_write_struct_csv(fullfile(directory,'certificate_summary.csv'),row);
leo_write_struct_csv(fullfile(directory,'certificate_trace.csv'),s.trace);
leo_write_struct_csv(fullfile(directory,'pricing_trace.csv'),s.pricingTrace);
fid=fopen(fullfile(directory,'CERTIFICATE.txt'),'w','n','UTF-8'); assert(fid>=0); cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'ORIGINAL %s, floor %.17g\nL=%.17g\nU=%.17g\nrelative gap=%.17g\ntarget met=%d\nstatus=%s\n', ...
    s.phase,s.floor,c.lower,c.upper,c.relativeGap,c.gapTargetMet,c.status);
fprintf(fid,'Actual log(1+SINR) per legal simultaneous group; original period margin subtracted once.\n');
fprintf(fid,'Pricing uses certified include/exclude beam trees. Every unclosed branch retains an optimistic bound.\n');
fprintf(fid,'The restricted LP primal objective is not an upper bound. Conditional throughput uses the explicit positive floor.\n');
fprintf(fid,'Certificate work is independent of all benchmark method scores and timings.\n');
fprintf(fid,'Numerical certificate uses double precision and explicit outward guards; it is not an exact-rational proof.\n');
files={}; if isempty(s.trace), return; end
units='Fairness ratio'; if strcmp(s.phase,'throughput'), units='Mbit per period'; end
p=leo_v14_panel('Original-model global interval','Certificate pricing sweep',units);
initial=s.initialLower; if ~isfinite(initial), initial=NaN; end
p=leo_v14_series(p,'Feasible lower',[0,[s.trace.sweep]],[initial,[s.trace.globalLower]]);
p=leo_v14_series(p,'Certified upper',[0,[s.trace.sweep]],[s.baselineUpper,[s.trace.globalUpper]]);
spec=struct('name','v15_original_certificate','title',sprintf('ORIGINAL %s certificate | floor %.9g | target met %d',s.phase,s.floor,c.gapTargetMet), ...
    'rows',1,'cols',1,'panels',p);
files=leo_v14_save_specs(spec,directory,'v15_certificate_specs',render);
end
