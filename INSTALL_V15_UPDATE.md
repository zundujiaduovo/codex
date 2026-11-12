# V15 安装

推荐将完整包 `LEO_QoS_Comparison_v15_from_v14_repaired_search_certified_bounds.zip` 解压到新目录。
已有项目要覆盖源码时，将 **平铺包** `V15_complete_source_update.zip` 直接解压到项目根目录，保留 `results/`。
`matlab/leo_v15_certificate.m` 必须直接位于项目根目录的 `matlab/` 下。

```matlab
cd('D:\code\LEO_QoS_Comparison_v15_from_v14_repaired_search_certified_bounds')
clear functions
addpath(fullfile(pwd,'matlab'),'-begin'); rehash;
CHECK_V15_INSTALLATION(pwd)
RUN_V15_ALL
```

平铺更新不删除旧结果。新五方法结果写入独立 V15 目录。
只认证已有 V14 结果：在 `V15_BOUND_SETTINGS.m` 设置 `sourceDirectory` 为含 `benchmark.mat` 的原结果目录，运行 `RUN_V15_BOUNDS`。
详细目标、求界公式和断点续算见 [V15_FROM_V14.md](V15_FROM_V14.md)。
