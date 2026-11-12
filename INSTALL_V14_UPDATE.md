# V14缺失文件或同名路径修复

`leo_v14_trust_path.m`是第二阶段修复版新增函数，正确位置为`项目根目录/matlab/leo_v14_trust_path.m`。完整包含此函数；仅覆盖入口脚本，或将带顶层目录的完整包再次解压到原工程里面，都可能导致安装检查失败。

下载`V14_complete_source_update.zip`（平铺完整更新包），把ZIP文件放到当前项目根目录。在MATLAB执行：

```matlab
projectRoot='D:\code\LEO_QoS_Comparison_v14_from_v13_fairness_coordination';
unzip(fullfile(projectRoot,'V14_complete_source_update.zip'),projectRoot);
cd(projectRoot)
clear functions
addpath(fullfile(projectRoot,'matlab'),'-begin'); rehash
CHECK_V14_INSTALLATION(projectRoot)
RUN_V14_ALL
```

平铺包中的`matlab/`与入口脚本直接位于ZIP根部，没有额外项目顶层目录，也不包含`results/`。解压会更新源码，不删除已保存实验。

`CHECK_V14_INSTALLATION`现在分别报告：

- `leo:v14MissingSource`：工程内确实缺少文件，并列出完整预期路径。
- `leo:v14ShadowedSource`：文件存在，但MATLAB加载了其他位置的同名文件，同时列出Expected和Actual。

如果仍报错，执行以下命令查看实际位置：

```matlab
exist(fullfile(projectRoot,'matlab','leo_v14_trust_path.m'),'file')
which leo_v14_trust_path -all
```

第一项应返回2；第二项应首先指向当前项目根目录下的`matlab/leo_v14_trust_path.m`。新完整实验写入`_stage2_v2`目录；只复用原第一阶段做第二阶段修复对照，可改运行`RUN_V14_STAGE2_REPAIR`。
