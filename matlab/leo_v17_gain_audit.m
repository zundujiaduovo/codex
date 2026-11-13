function a=leo_v17_gain_audit(actual,predicted,tolerance)
% Gains share the same incumbent, weights, physical block and candidate domain.
actual=reshape(actual,1,[]); predicted=reshape(predicted,1,[]);
denominator=max(tolerance,max(abs(actual),abs(predicted)));
relative=abs(actual-predicted)./denominator;
meaningful=max(abs(actual),abs(predicted))>tolerance;
a=struct('count',numel(actual),'maxRelativeError',max([0,relative]), ...
    'signReversals',nnz(meaningful & actual.*predicted<0), ...
    'normalizedRmsError',norm(actual-predicted)/max(tolerance,norm(actual)), ...
    'actual',actual,'predicted',predicted);
end
