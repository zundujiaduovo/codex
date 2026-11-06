function o = leo_predict_orbit(p,r)
%LEO_PREDICT_ORBIT 连续圆轨道 ECI -> ECEF；合成星历，不是 TLE/SGP4。
% 接口标注：
% 输入：p：轨道及地球参数；r：基本槽采样时刻。
% 输出：o：3×T 轨道位置 m、速度及 3×3×T 阵列姿态。
% 阵列 +z 指向地心，+x 为惯性轨道速度在切平面的方向，R 为右手系。
T = p.time.nSlots;
radius = p.earth.aM+p.orbit.altitudeM;
n = sqrt(p.earth.mu/radius^3);
inc = p.orbit.inclinationDeg*pi/180;
raan = p.orbit.raanDeg*pi/180;
Q = [cos(raan),-sin(raan),0;sin(raan),cos(raan),0;0,0,1] * ...
    [1,0,0;0,cos(inc),-sin(inc);0,sin(inc),cos(inc)];
o.ecefM = zeros(3,T);
o.velocityEcefMS = zeros(3,T);
o.arrayToEcef = zeros(3,3,T);
o.periodS = 2*pi/n;
for t = 1:T
    arg = p.orbit.initialArgumentDeg*pi/180+n*r.sampleTimeS(t);
    pos = Q*(radius*[cos(arg);sin(arg);0]);
    vel = Q*(radius*n*[-sin(arg);cos(arg);0]);
    angle = p.orbit.earthAngleAtEpochDeg*pi/180 + ...
        p.earth.rotationRadS*r.sampleTimeS(t);
    E = [cos(angle),sin(angle),0;-sin(angle),cos(angle),0;0,0,1];
    pos = E*pos;
    inertialVel = E*vel;
    o.ecefM(:,t) = pos;
    o.velocityEcefMS(:,t) = inertialVel-cross([0;0;p.earth.rotationRadS],pos);
    z = -pos/norm(pos);
    x = inertialVel-z*(z.'*inertialVel);
    x = x/norm(x);
    y = cross(z,x);
    o.arrayToEcef(:,:,t) = [x,y,z];
end
end
