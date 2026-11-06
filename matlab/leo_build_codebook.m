function cb = leo_build_codebook(p)
%LEO_BUILD_CODEBOOK [C5-C8] 固定网格、有限相位、首阵元归零、稳定去重。
% 接口标注：
% 输入：p：固定候选网格、量化位数、码本大小。
% 输出：cb：Na×NB 合法复码字及对应方向元数据。
% 不读取用户/轨道。以 (r,s) 字典序编号；量化平局采用 MATLAB round。
[ix,iy] = ndgrid(0:p.array.nX-1,0:p.array.nY-1);
levels = 2^p.array.phaseBits;
codes = zeros(p.array.nElements,0);
directions = zeros(3,0);
indices = zeros(2,0);
for r = 0:p.array.gridX-1
    xi = -0.5+r/p.array.gridX;
    for s = 0:p.array.gridY-1
        eta = -0.5+s/p.array.gridY;
        ux = xi/p.array.spacingWavelength(1);
        uy = eta/p.array.spacingWavelength(2);
        if ux^2+uy^2>sin(p.array.scanMaxDeg*pi/180)^2+1e-14
            continue;
        end
        phaseIndex = mod(round(levels*(ix(:)*xi+iy(:)*eta)),levels);
        phaseIndex = mod(phaseIndex-phaseIndex(1),levels);
        if ~isempty(codes) && any(all(bsxfun(@eq,codes,phaseIndex),1))
            continue;
        end
        codes(:,end+1) = phaseIndex; %#ok<AGROW>
        directions(:,end+1) = [ux;uy;sqrt(max(0,1-ux^2-uy^2))]; %#ok<AGROW>
        indices(:,end+1) = [r;s]; %#ok<AGROW>
    end
end
cb.nBeams = size(codes,2);
assert(cb.nBeams>=p.system.maxStreams,'码本波束数少于 L，请检查网格和扫描域。');
cb.phaseIndex = codes;
cb.F = exp(1i*2*pi*codes/levels)/sqrt(p.array.nElements);
cb.directionArray = directions;
cb.gridIndex = indices;
% C9: 量化后仍须满足每个生成网格中心的理论增益下界。
a = leo_array_response(p,directions);
cb.centerGain = abs(sum(conj(a).*cb.F,1)).^2;
assert(all(cb.centerGain>=cos(pi/levels)^2-1e-12));
cb = leo_select_codebook(p,cb);
end
