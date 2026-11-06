function [positionM, up] = leo_geodetic_to_ecef(latDeg,lonDeg,heightM,earth)
%LEO_GEODETIC_TO_ECEF [G1-G2] WGS-84 大地坐标与椭球向上法向，输出 3xK。
% 接口标注：
% 输入：latDeg/lonDeg/heightM：大地坐标；earth：WGS-84 参数。
% 输出：positionM、up：3×K ECEF 坐标 m 与单位向上向量。
lat = latDeg(:).'*pi/180;
lon = lonDeg(:).'*pi/180;
h = heightM(:).';
nu = earth.aM./sqrt(1-earth.e2*sin(lat).^2);
positionM = [(nu+h).*cos(lat).*cos(lon); ...
    (nu+h).*cos(lat).*sin(lon);((1-earth.e2)*nu+h).*sin(lat)];
up = [cos(lat).*cos(lon);cos(lat).*sin(lon);sin(lat)];
end
