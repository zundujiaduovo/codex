function name = leo_method_name(id)
%LEO_METHOD_NAME 对外方法名称；旧结果重画时也去除引擎版本后缀。
switch id
    case {'original_tabu','Tabu'}, name='Tabu';
    case {'sb_v12_lexicographic','sb_v8_blockwise','SB'}, name='SB';
    case {'local_v12_lexicographic','local_v8_blockwise','Local'}, name='Local';
    case {'original_greedy','Greedy'}, name='Greedy';
    otherwise, name=id;
end
end
