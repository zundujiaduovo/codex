function yes = leo_is_lexicographic(data)
%LEO_IS_LEXICOGRAPHIC V12未封顶max-min目标；无标记旧快照按原版本解释。
yes=isfield(data,'objectiveMode') && strcmp(data.objectiveMode,'lexicographic_max_min');
end
