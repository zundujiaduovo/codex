function o=leo_v12_method_options(overrides)
% Shared validated options for the current coordinated solver.
if nargin<1, overrides=struct(); end
o=leo_method_options(overrides);
end
