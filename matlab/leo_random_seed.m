function seed = leo_random_seed()
%LEO_RANDOM_SEED 从系统随机源生成单个种子；不改动调用方的 MATLAB 随机流。
% Windows/MATLAB 优先使用 Java SecureRandom；Unix/Octave 优先 /dev/urandom。
if ~ispc
    fid = fopen('/dev/urandom','rb');
    if fid>=0
        cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
        x = fread(fid,1,'uint32=>double');
        if ~isempty(x), seed = x; return; end
    end
end
try
    randomSource = javaObject('java.security.SecureRandom');
    seed = double(randomSource.nextInt(int32(2147483647)));
    return;
catch
    % 无系统/Java 随机源时，仅退回 MATLAB 自带 shuffle，并恢复调用方状态。
    previous = rng; cleanup = onCleanup(@() rng(previous)); %#ok<NASGU>
    rng('shuffle'); seed = randi([0,2147483646]);
end
end
