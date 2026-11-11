function fairness = leo_fairness_from_ratios(data,ratios)
%LEO_FAIRNESS_FROM_RATIOS 每列一个完整日程，先跨时隙累计服务再取最差用户。
fairness=min(ratios,[],1);
if ~leo_is_lexicographic(data), fairness=min(1,fairness); end
end
