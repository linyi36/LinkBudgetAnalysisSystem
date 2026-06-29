%% Tool_TestPatternGenerator.m
% =========================================================================
% 脚本: Tool_TestPatternGenerator (测试天线方向图生成器 - 扩展版)
% 描述: 基于 MATLAB Antenna Toolbox，生成多种典型天线(偶极子、微带贴片、反射面)
%       的 3D 辐射方向图。代码内置了坐标系对齐逻辑(Elevation 转 Theta)，
%       最终将数据展平并导出为链路仿真系统可直接读取的标准化 CSV 文件。
%       支持高扩展性 switch-case 架构，便于后续扩充天线库。
% 
% 作者: 林怡 & gemmi
% 版本: 2026/6/18
%
% 输入 (内部用户配置参数):
%   - TargetFreq      : 目标工作频率 (单位: Hz)。默认: 4.95e9 (4.95 GHz)
%   - SelectedAntenna : 拟生成的天线类型。支持: 
%                       'Dipole'   (偶极子，全向)
%                       'Patch'    (微带贴片，定向半球)
%                       'Reflector'(反射面，高定向窄波束)
%
% 输出 :
%   - CSV 结果文件    : test_pattern_[类型].csv，包含标准的三列: 
%                       phi (0~360度), theta (天顶角 0~180度), realizedgain (dBi)
%                       (注: 产物将统一自动输出至 AntennaPatternAnalyzer/input 目录下)
%   - Figure (Fig.1)  : 选定天线的物理结构预览图
%   - Figure (Fig.2)  : 选定天线在指定频率下的 3D 辐射方向图
% =========================================================================

clear; clc; close all;

%% 1. 测试参数与天线类型选择区
TargetFreq = 4.95e9; % 工作频率：4.95 GHz

% 【路径优化】：自动获取当前脚本路径，统一将产物存放到分析器的 input 文件夹中
CurrentDir = fileparts(mfilename('fullpath'));
ExportFolder = fullfile(CurrentDir, 'AntennaPatternAnalyzer', 'input'); 
if ~exist(ExportFolder, 'dir')
    mkdir(ExportFolder); 
end

% ==========================================
%  在这里切换你想生成的天线类型 
% 可选值: 'Dipole' (偶极子), 'Patch' (微带贴片), 'Reflector' (反射面)
SelectedAntenna = 'Dipole'; 
% ==========================================

ExportFile = fullfile(ExportFolder, sprintf('test_pattern_%s.csv', lower(SelectedAntenna)));

fprintf('--- 启动测试天线方向图生成器 ---\n');
fprintf('目标频率: %.2f GHz | 选择天线: %s\n', TargetFreq/1e9, SelectedAntenna);
fprintf('统一输出路径: %s\n', ExportFolder);

%% 2. 构建天线模型 (高扩展性架构)
switch lower(SelectedAntenna)
    case 'dipole'
        % 1. 偶极子天线 (经典全向/甜甜圈)
        % 用途：测试基础的全向辐射、无偏角的基准测试
        ant = dipole;
        design(ant, TargetFreq);
        
    case 'patch'
        % 2. 微带贴片天线 (典型定向/半球形)
        % 用途：测试无人机常用的单面定向天线
        ant = patchMicrostrip;
        design(ant, TargetFreq);
        % 将主波束指向调整为 X轴正向 (正东)
        ant.Tilt = 90;
        ant.TiltAxis = [0 1 0];
        
    case 'reflector'
        % 3. 反射面天线 (极高定向/窄波束)
        % 用途：测试地面站、雷达等极窄波束的精准 3D 旋转跟踪
        ant = reflector;
        ant.Exciter = dipole;
        design(ant, TargetFreq);
        % 将主波束指向调整为 X轴正向 (正东)
        ant.Tilt = 90;
        ant.TiltAxis = [0 1 0];
        
    otherwise
        error('未识别的天线类型，请检查 SelectedAntenna 变量。');
end

% 预览物理结构
figure('Name', sprintf('%s Structure', SelectedAntenna), 'Color', 'w');
show(ant);
title(sprintf('天线物理结构: %s', SelectedAntenna));

%% 3. 计算 3D 辐射方向图数据
fprintf('正在计算全空间 3D 方向图数据...\n');
AzimuthSteps = 0:2:360;
ElevationSteps = -90:2:90; 

% 注意：pattern 函数返回的 azVec 和 elVec 是一维向量
[gainDb, azVec, elVec] = pattern(ant, TargetFreq, AzimuthSteps, ElevationSteps);

% 预览 3D 效果
figure('Name', sprintf('%s 3D Pattern', SelectedAntenna), 'Color', 'w');
pattern(ant, TargetFreq);
title(sprintf('%s 3D 方向图', SelectedAntenna));

% 强制开启 3D 视图的手动旋转功能
rotate3d on; 

%% 4. 数据格式对齐与 CSV 导出
fprintf('正在格式化数据并导出...\n');

% 【修复核心】：将一维坐标轴向量转为二维网格矩阵，使其与 gainDb 大小一致
[azMesh, elMesh] = meshgrid(azVec, elVec);

% 将仰角 (-90~90) 转换为 天顶角 Theta (0~180)
thetaMesh = 90 - elMesh;

% 展平数据（此时三个矩阵的尺寸完全一致了）
Az_flat = azMesh(:);
Theta_flat = thetaMesh(:);
Gain_flat = gainDb(:);

% 过滤极小值
Gain_flat(Gain_flat < -100) = -100;

% 构建 Table 并写入
T = table(Az_flat, Theta_flat, Gain_flat, 'VariableNames', {'phi', 'theta', 'realizedgain'});
writetable(T, ExportFile);

fprintf(' 测试数据生成完毕！文件路径: %s\n', ExportFile);