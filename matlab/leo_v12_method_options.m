function o = leo_v12_method_options(overrides)
%LEO_V12_METHOD_OPTIONS 冻结内层参数外增加可选停止设置，不修改V8历史文件。
if nargin<1, overrides=struct(); end
hasStopping=isfield(overrides,'stopping');
if hasStopping, stop=leo_stopping_options(overrides.stopping); overrides=rmfield(overrides,'stopping'); end
o=leo_v8_method_options(overrides);
if hasStopping, o.stopping=stop; end
end
