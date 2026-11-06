function a = leo_array_response(p,direction)
%LEO_ARRAY_RESPONSE [C1] 每列单位范数，p 索引优先变化，与码本一致。
% 接口标注：
% 输入：p：UPA 参数；direction：3×N 阵列坐标系单位方向。
% 输出：a：Na×N 单位范数复阵列响应。
[ix,iy] = ndgrid(0:p.array.nX-1,0:p.array.nY-1);
phase = 2*pi*(p.array.spacingWavelength(1)*ix(:)*direction(1,:) + ...
              p.array.spacingWavelength(2)*iy(:)*direction(2,:));
a = exp(1i*phase)/sqrt(p.array.nElements);
end
