function g = leo_compute_geometry(p,u,o)
%LEO_COMPUTE_GEOMETRY [G3-G4] 斜距、仰角、阵列出射方向、正面扫描条件。
% 接口标注：
% 输入：p：覆盖门槛；u/o：用户与卫星轨道结构。
% 输出：g：K×T 距离、仰角、可见性及 3×K×T 阵列方向。
K = p.system.K; T = p.time.nSlots;
g.rangeM = zeros(K,T);
g.elevationDeg = zeros(K,T);
g.directionArray = zeros(3,K,T);
g.offAxisDeg = zeros(K,T);
for t = 1:T
    userToSat = bsxfun(@minus,o.ecefM(:,t),u.ecefM);
    distance = sqrt(sum(userToSat.^2,1));
    assert(all(distance>0));
    los = bsxfun(@rdivide,userToSat,distance);
    direction = o.arrayToEcef(:,:,t).'* (-los);
    g.rangeM(:,t) = distance.';
    g.elevationDeg(:,t) = asin(max(-1,min(1,sum(los.*u.up,1)))).'*180/pi;
    g.directionArray(:,:,t) = direction;
    g.offAxisDeg(:,t) = acos(max(-1,min(1,direction(3,:)))).'*180/pi;
end
g.visible = g.elevationDeg>=p.coverage.minElevationDeg & ...
    g.offAxisDeg<=p.array.scanMaxDeg;
D = norm([(p.array.nX-1)*p.array.spacingM(1), ...
          (p.array.nY-1)*p.array.spacingM(2)]);
g.fraunhoferDistanceM = 2*D^2/p.system.wavelengthM;
assert(min(g.rangeM(:))>100*g.fraunhoferDistanceM, ...
    '当前几何不能充分支持远场近似。');
end
