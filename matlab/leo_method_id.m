function id = leo_method_id(name)
%LEO_METHOD_ID 清晰方法名到历史引擎ID的映射，旧缓存和求解引擎保持可读。
switch name
    case 'Tabu', id='original_tabu';
    case 'SB', id='sb_v12_lexicographic';
    case 'Local', id='local_v12_lexicographic';
    case 'Proxy+Tabu', id='proxy_tabu';
    case 'Greedy', id='original_greedy';
    otherwise, id=name;
end
end
