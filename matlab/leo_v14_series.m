function p=leo_v14_series(p,name,x,y)
p.series=leo_append_struct(p.series,struct('name',name,'x',x(:).','y',y(:).','low',[],'high',[]));
end
