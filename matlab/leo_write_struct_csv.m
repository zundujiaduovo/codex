function leo_write_struct_csv(path,rows)
%LEO_WRITE_STRUCT_CSV 导出标量结构体表，UTF-8；字符串引号/逗号正确转义。
% 输入：输出路径、同字段结构体数组。输出：CSV 文件；NaN 表示不适用/未运行。
fid = fopen(path,'w','n','UTF-8'); assert(fid>=0,['无法写文件: ',path]);
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
if isempty(rows), return; end
names = fieldnames(rows);
fprintf(fid,'%s\n',strjoin(names.',',')); % 字段名为 MATLAB 标识符
for r = 1:numel(rows)
    cells = cell(1,numel(names));
    for j = 1:numel(names)
        v = rows(r).(names{j});
        if ischar(v), cells{j} = ['"',strrep(v,'"','""'),'"'];
        else, assert(isscalar(v)); cells{j} = sprintf('%.17g',v); end
    end
    fprintf(fid,'%s\n',strjoin(cells,','));
end
end
