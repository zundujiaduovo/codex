function rows = leo_append_struct(rows,item)
%LEO_APPEND_STRUCT 向空或已有的结构体数组追加一行，兼容 MATLAB。
% 首次直接赋值建立字段；后续按下标追加，保留字段不一致的正常错误。
assert(isstruct(rows) && isstruct(item) && isscalar(item));
if isempty(rows)
    rows = item;
else
    rows(end+1,1) = item;
end
end
