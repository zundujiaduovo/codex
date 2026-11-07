function rows = leo_append_struct(rows,row)
%LEO_APPEND_STRUCT MATLAB/Octave 通用结构体追加，首条记录直接建立字段结构。
assert(isstruct(row) && isscalar(row));
if isempty(rows)
    rows = row;
else
    rows(end+1,1) = orderfields(row,rows);
end
end
