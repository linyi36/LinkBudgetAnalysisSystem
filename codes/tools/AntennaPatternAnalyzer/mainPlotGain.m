% /*!
% * @brief 天线方向图分析小工具主脚本。
% * @details 本脚本从 input 文件夹读取方向图 CSV，绘制 Phi/Theta/Gain 二维等高线图，
% *          保留老师原版 Fig.100/Fig.200/Fig.300/Fig.400 四类方向图，
% *          同时绘制固定 Phi/Theta 的一维切面，统计指定角度区域内 Gain 的
% *          min/mean/max/median/std 以及 Gain 大于阈值的比例，并将 PNG、CSV
% *          和 TXT 报告保存到 output 文件夹；可自动打开 Phi/Theta 交互查询界面。
% * @pre tools/AntennaPatternAnalyzer/input 中存在方向图 CSV 文件。
% * @bug Null
% * @warning 若 CSV 中存在频率列，将自动选择最接近 TargetFreqGHz 的频点。
% * @author Lin Yi
% * @version 2.5
% * @date 2026.05.30
% * @copyright Null
% * @remark { revision history: 2026.05.30. V2.5, Lin Yi, keep teacher Fig.100/200/300/400 and add ROI UI. }
% */

clear; clc; close all;

%% 0. 路径设置
ToolDir   = fileparts(mfilename('fullpath'));
InputDir  = fullfile(ToolDir, 'input');
OutputDir = fullfile(ToolDir, 'output');

if ~exist(InputDir, 'dir')
    error('输入文件夹不存在：%s', InputDir);
end

if ~exist(OutputDir, 'dir')
    mkdir(OutputDir);
end

addpath(genpath(ToolDir));

fprintf('\n========== AntennaPatternAnalyzer ==========\n');
fprintf('Tool dir   : %s\n', ToolDir);
fprintf('Input dir  : %s\n', InputDir);
fprintf('Output dir : %s\n', OutputDir);
fprintf('============================================\n');

%% 1. 用户配置区
Cfg = struct();
Cfg.PatternFileName = '314B_Air_RealizedGainPlot.csv';
Cfg.TargetFreqGHz   = 4.95;

Cfg.RegionName      = 'TailPm15';
Cfg.PhiRangeDeg     = [75, 105];
Cfg.ThetaRangeDeg   = [75, 105];
Cfg.GainThresholdDb = -5;

Cfg.FixedThetaListDeg = [75, 90, 105];
Cfg.FixedPhiListDeg   = [90, 270];

Cfg.FlagShowFigure = true;
Cfg.FlagOpenSlider = true;

%% 2. 检查输入文件
PatternFilePath = fullfile(InputDir, Cfg.PatternFileName);
if ~exist(PatternFilePath, 'file')
    error('方向图 CSV 文件不存在：%s', PatternFilePath);
end

[~, PatternName, ~] = fileparts(Cfg.PatternFileName);
PatternOutDir = fullfile(OutputDir, PatternName);
if ~exist(PatternOutDir, 'dir')
    mkdir(PatternOutDir);
end

fprintf('\n========== Input Configuration ==========\n');
fprintf('Pattern file      : %s\n', PatternFilePath);
fprintf('Target frequency  : %.3f GHz\n', Cfg.TargetFreqGHz);
fprintf('Region name       : %s\n', Cfg.RegionName);
fprintf('Phi range         : %.2f ~ %.2f deg\n', Cfg.PhiRangeDeg(1), Cfg.PhiRangeDeg(2));
fprintf('Theta range       : %.2f ~ %.2f deg\n', Cfg.ThetaRangeDeg(1), Cfg.ThetaRangeDeg(2));
fprintf('Gain threshold    : %.3f dBi\n', Cfg.GainThresholdDb);
fprintf('Fixed Theta list  : %s\n', mat2str(Cfg.FixedThetaListDeg));
fprintf('Fixed Phi list    : %s\n', mat2str(Cfg.FixedPhiListDeg));
fprintf('Show figure       : %d\n', Cfg.FlagShowFigure);
fprintf('Open slider       : %d\n', Cfg.FlagOpenSlider);
fprintf('=========================================\n');

%% 3. 读取方向图
Pattern = ReadAntennaPatternCsv(PatternFilePath, Cfg.TargetFreqGHz);

%% 4. 绘制老师原版方向图：Fig.100/200/300/400
% Fig.100: 二维伪彩色图
% Fig.200: 二维等高线图 + 实线 + ROI 标注
% Fig.300: 三维极坐标方向图
% Fig.400: patternCustom 三维方向图，若无 Antenna Toolbox 则自动跳过
OverviewResult = PlotPatternOverviewFigures(Pattern, Cfg, PatternOutDir, Cfg.FlagShowFigure);
ContourPath = OverviewResult.ContourRoiPng;

%% 5. 绘制一维切面图
CutResult = PlotPatternCuts(Pattern, ...
    Cfg.FixedThetaListDeg, ...
    Cfg.FixedPhiListDeg, ...
    Cfg.GainThresholdDb, ...
    PatternOutDir, ...
    Cfg.FlagShowFigure);

%% 6. 指定区域增益统计
RegionStats = AnalyzeGainRegion(Pattern, ...
    Cfg.PhiRangeDeg, ...
    Cfg.ThetaRangeDeg, ...
    Cfg.GainThresholdDb, ...
    Cfg.RegionName);

RegionCsvPath = fullfile(PatternOutDir, [PatternName, '_RegionStats.csv']);
writetable(struct2table(RegionStats), RegionCsvPath);

%% 7. 关键方向增益表
KeyDirTable = BuildKeyDirectionGainTable(Pattern);
KeyDirCsvPath = fullfile(PatternOutDir, [PatternName, '_KeyDirectionGain.csv']);
writetable(KeyDirTable, KeyDirCsvPath);

%% 8. 输出 TXT 简要报告
ReportPath = fullfile(PatternOutDir, [PatternName, '_AnalysisReport.txt']);
WritePatternAnalysisReport(ReportPath, Pattern, Cfg, RegionStats, KeyDirTable, CutResult);

%% 9. 打开 Phi / Theta 滑块 + 手动输入交互界面
if Cfg.FlagOpenSlider
    fprintf('\n正在打开 Phi / Theta 滑块交互界面...\n');
    if exist('OpenPatternSlider', 'file') == 2
        OpenPatternSlider(Pattern, Cfg);
    else
        warning('未找到 OpenPatternSlider.m，请检查该文件是否在 tools/AntennaPatternAnalyzer 目录下。');
    end
end

%% 10. 控制台输出总结
PrintRegionStatsSafe(RegionStats, Cfg);

fprintf('\n========== AntennaPatternAnalyzer finished ==========\n');
fprintf('Input file : %s\n', PatternFilePath);
fprintf('Output dir : %s\n', PatternOutDir);
fprintf('Fig100 PNG : %s\n', OverviewResult.HeatmapPng);
fprintf('Fig200 PNG : %s\n', OverviewResult.ContourRoiPng);
fprintf('Fig300 PNG : %s\n', OverviewResult.Spherical3dPng);
if isfield(OverviewResult, 'PatternCustomGenerated') && OverviewResult.PatternCustomGenerated
    fprintf('Fig400 PNG : %s\n', OverviewResult.PatternCustomPng);
else
    fprintf('Fig400 PNG : skipped, Antenna Toolbox patternCustom unavailable or failed.\n');
end
fprintf('Region CSV : %s\n', RegionCsvPath);
fprintf('KeyDir CSV : %s\n', KeyDirCsvPath);
fprintf('Report TXT : %s\n', ReportPath);

if isstruct(CutResult)
    if isfield(CutResult, 'FixedThetaFigurePath')
        fprintf('Theta cuts : %s\n', CutResult.FixedThetaFigurePath);
    end
    if isfield(CutResult, 'FixedPhiFigurePath')
        fprintf('Phi cuts   : %s\n', CutResult.FixedPhiFigurePath);
    end
end
fprintf('====================================================\n');

%% ========================================================================
%  局部函数：安全打印 RegionStats
% =========================================================================
function PrintRegionStatsSafe(RegionStats, Cfg)

fprintf('\n========== Region Gain Statistics ==========\n');

if isfield(RegionStats, 'RegionName')
    fprintf('Region       : %s\n', string(RegionStats.RegionName));
else
    fprintf('Region       : %s\n', string(Cfg.RegionName));
end

if isfield(RegionStats, 'PhiMinDeg') && isfield(RegionStats, 'PhiMaxDeg')
    fprintf('Phi range    : %.2f ~ %.2f deg\n', RegionStats.PhiMinDeg, RegionStats.PhiMaxDeg);
else
    fprintf('Phi range    : %.2f ~ %.2f deg\n', Cfg.PhiRangeDeg(1), Cfg.PhiRangeDeg(2));
end

if isfield(RegionStats, 'ThetaMinDeg') && isfield(RegionStats, 'ThetaMaxDeg')
    fprintf('Theta range  : %.2f ~ %.2f deg\n', RegionStats.ThetaMinDeg, RegionStats.ThetaMaxDeg);
else
    fprintf('Theta range  : %.2f ~ %.2f deg\n', Cfg.ThetaRangeDeg(1), Cfg.ThetaRangeDeg(2));
end

fprintf('Threshold    : %.3f dBi\n', Cfg.GainThresholdDb);

fprintf('Gain min/mean/max/median/std = %.3f / %.3f / %.3f / %.3f / %.3f dBi\n', ...
    RegionStats.GainMinDb, ...
    RegionStats.GainMeanDb, ...
    RegionStats.GainMaxDb, ...
    RegionStats.GainMedianDb, ...
    RegionStats.GainStdDb);

if isfield(RegionStats, 'PercentAboveThreshold')
    PercentAbove = RegionStats.PercentAboveThreshold;
elseif isfield(RegionStats, 'GainAboveThresholdPercent')
    PercentAbove = RegionStats.GainAboveThresholdPercent;
elseif isfield(RegionStats, 'PercentGreaterThanThreshold')
    PercentAbove = RegionStats.PercentGreaterThanThreshold;
else
    PercentAbove = NaN;
end

if isnan(PercentAbove)
    fprintf('Gain > threshold percent = 未找到对应字段，请检查 AnalyzeGainRegion.m 输出字段名。\n');
else
    fprintf('Gain > threshold percent = %.2f %%\n', PercentAbove);
end

fprintf('============================================\n');

end
