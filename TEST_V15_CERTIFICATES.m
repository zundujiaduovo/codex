% Small exhaustive original-model tests; no 64-user performance experiment.
comparisonRoot=fileparts(mfilename('fullpath'));
CHECK_V15_INSTALLATION(comparisonRoot);
test_leo_v15_certificates();
