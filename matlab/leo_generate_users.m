function u = leo_generate_users(p)
%LEO_GENERATE_USERS 固定用户：先在球面帽均匀取点，再用 WGS-84 转 ECEF。
% 接口标注：
% 输入：p：用户区域、数量及地球参数。
% 输出：u：固定用户经纬度、3×K ECEF 坐标 m 和局部法向。
% 球面帽仅用于区域采样，不能声称在椭球表面严格等面积。
K = p.system.K;
lat0 = p.users.centerLatDeg*pi/180;
lon0 = p.users.centerLonDeg*pi/180;
cap = p.users.radiusM/p.earth.aM;
fixed = strcmp(p.users.layout,'reference32') && K==32 && ...
    p.users.centerLatDeg==0 && p.users.centerLonDeg==0 && p.users.radiusM==200e3;
if fixed
    [u.latDeg,u.lonDeg] = leo_reference_users_32();
    % 保留历史默认样本对随机流的消耗，衰落样本仍由原 seed 生成。
    rand(1,K); rand(1,K);
else
    delta = acos(1-rand(1,K)*(1-cos(cap)));
    bearing = 2*pi*rand(1,K);
    lat = asin(sin(lat0)*cos(delta)+cos(lat0)*sin(delta).*cos(bearing));
    lon = lon0+atan2(sin(bearing).*sin(delta)*cos(lat0), ...
        cos(delta)-sin(lat0)*sin(lat));
    u.latDeg = lat*180/pi;
    u.lonDeg = mod(lon*180/pi+180,360)-180;
end
u.heightM = repmat(p.users.altitudeM,1,K);
[u.ecefM,u.up] = leo_geodetic_to_ecef(u.latDeg,u.lonDeg,u.heightM,p.earth);
end
