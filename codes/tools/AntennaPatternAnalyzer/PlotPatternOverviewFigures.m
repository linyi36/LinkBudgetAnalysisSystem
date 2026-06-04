function OverviewResult = PlotPatternOverviewFigures(Pattern, Cfg, OutputDir, FlagShowFigure)
% /*!
% * @brief 绘制原版方向图中的伪彩色图、等高线图、3D 球坐标方向图和 patternCustom 图。
% * @details 保留老师原版 Fig.100/Fig.200/Fig.300/Fig.400 的图名和绘图逻辑。
% *          Fig.100 为二维伪彩色热力图；
% *          Fig.200 为二维等高线图，并叠加实线等高线、ROI 边框、最大/最小值标记；
% *          Fig.300 为三维极坐标方向图；
% *          Fig.400 为 patternCustom 三维方向图。
% * @param[in] Pattern, struct, 方向图结构体。
% * @param[in] Cfg, struct, 主脚本配置，包含 ROI 和阈值信息。
% * @param[in] OutputDir, char/string, 输出目录。
% * @param[in] FlagShowFigure, logical, 是否显示图窗。
% * @param[out] OverviewResult, struct, 输出文件路径和 ROI 统计结果。
% * @pre Pattern 中需包含 PhiGrid、ThetaGrid、GainGrid、PhiUnique、ThetaUnique。
% * @bug Null
% * @warning Fig.400 需要 Antenna Toolbox 中的 patternCustom 函数。
% * @author Lin Yi
% * @version 2.1
% * @date 2026.06.04
% * @copyright Null
% * @remark { revision history:
% *   2026.06.04. V2.0, Lin Yi, add teacher original Fig.100/Fig.200/Fig.300/Fig.400.
% *   2026.06.04. V2.1, Lin Yi, restore teacher original figure titles.
% * }
% */

if nargin < 4 || isempty(FlagShowFigure)
    FlagShowFigure = true;
end

if ~exist(OutputDir, 'dir')
    mkdir(OutputDir);
end

PhiGrid     = Pattern.PhiGrid;
ThetaGrid   = Pattern.ThetaGrid;
GainGrid    = Pattern.GainGrid;
PhiUnique   = Pattern.PhiUnique;
ThetaUnique = Pattern.ThetaUnique;
PatternName = Pattern.FileBaseName;

OverviewResult = struct();

% 文件名可以保留 Fig.100 / Fig.200 / Fig.300 / Fig.400 标识，方便和老师原版对应
OverviewResult.HeatmapPng       = fullfile(OutputDir, [PatternName, '_Fig100_天线方向增益二维分布图.png']);
OverviewResult.ContourRoiPng    = fullfile(OutputDir, [PatternName, '_Fig200_天线方向增益等高线图.png']);
OverviewResult.Spherical3dPng   = fullfile(OutputDir, [PatternName, '_Fig300_天线三维极坐标方向图.png']);
OverviewResult.PatternCustomPng = fullfile(OutputDir, [PatternName, '_Fig400_patternCustom三维方向图.png']);

VisibleState = 'off';
if FlagShowFigure
    VisibleState = 'on';
end

%% Fig.100 二维伪彩色热力图
figure(100);
Fig100 = gcf;
set(Fig100, 'Visible', VisibleState, 'Color', 'w');
clf(Fig100);

pcolor(PhiGrid, ThetaGrid, GainGrid);
shading interp;
colorbar;
colormap(jet);
grid on;

xlabel('\phi 方位角 (deg)');
ylabel('\theta 俯仰角 (deg)');
title('天线方向增益二维分布图 (dBi)');

SaveFigureLocal(Fig100, OverviewResult.HeatmapPng);

%% Fig.200 二维等高线图 + ROI
figure(200);
Fig200 = gcf;
set(Fig200, 'Visible', VisibleState, 'Color', 'w');
clf(Fig200);

% 彩色填充等高线
contourf(PhiGrid, ThetaGrid, GainGrid, 20, 'LineColor', 'none');
hold on;

% 叠加实线等高线，让边界更明显
contour(PhiGrid, ThetaGrid, GainGrid, 20, ...
    'LineColor', [0.12 0.12 0.12], ...
    'LineStyle', '-', ...
    'LineWidth', 0.35);

colorbar;
colormap(jet);
grid on;

xlabel('\phi 方位角 (deg)');
ylabel('\theta 俯仰角 (deg)');
title('天线方向增益等高线图 (dBi)');

OverviewResult.RoiStats = AnalyzeRoiForPlotLocal( ...
    PhiGrid, ThetaGrid, GainGrid, ...
    Cfg.PhiRangeDeg(1), Cfg.PhiRangeDeg(2), ...
    Cfg.ThetaRangeDeg(1), Cfg.ThetaRangeDeg(2), ...
    Cfg.GainThresholdDb);

DrawRoiOnAxesLocal(gca, OverviewResult.RoiStats);

SaveFigureLocal(Fig200, OverviewResult.ContourRoiPng);

%% Fig.300 三维极坐标方向图
% 原理：
%   r = 10^(gain_dBi / 20)
%   x = r * sin(theta) * cos(phi)
%   y = r * sin(theta) * sin(phi)
%   z = r * cos(theta)
%
% 形状使用真实线性幅度，颜色使用真实 dBi。

figure(300);
Fig300 = gcf;
set(Fig300, 'Visible', VisibleState, 'Color', 'w');
clf(Fig300);

GainLinear = 10 .^ (GainGrid ./ 20);

PhiRad   = deg2rad(PhiGrid);
ThetaRad = deg2rad(ThetaGrid);

XCoord = GainLinear .* sin(ThetaRad) .* cos(PhiRad);
YCoord = GainLinear .* sin(ThetaRad) .* sin(PhiRad);
ZCoord = GainLinear .* cos(ThetaRad);

surf(XCoord, YCoord, ZCoord, GainGrid);
shading interp;

ColorBarHandle = colorbar;
ColorBarHandle.Label.String = '增益 (dBi)';
colormap(jet);

axis equal;
grid on;

xlabel('X  [\phi=0°, \theta=90°]');
ylabel('Y  [\phi=90°, \theta=90°]');
zlabel('Z  [\theta=0°]');
title('天线三维极坐标方向图 (形状: 真实线性幅度, 颜色: 真实 dBi)');

view(45, 30);

SaveFigureLocal(Fig300, OverviewResult.Spherical3dPng);

%% Fig.400 patternCustom 方向图，Antenna Toolbox 可用时生成
figure(400);
Fig400 = gcf;
set(Fig400, 'Visible', VisibleState, 'Color', 'w');
clf(Fig400);

try
    if exist('patternCustom', 'file') == 2
        % patternCustom 要求：
        %   magE      : nPhi x nTheta
        %   theta_vec : 1 x nTheta
        %   phi_vec   : 1 x nPhi
        %
        % GainGrid 是 nTheta x nPhi，因此需要转置。
        patternCustom(GainGrid.', ThetaUnique.', PhiUnique.');
        title('天线三维方向图 - patternCustom (dBi)');

        SaveFigureLocal(Fig400, OverviewResult.PatternCustomPng);
        OverviewResult.PatternCustomGenerated = true;
    else
        warning('PlotPatternOverviewFigures:NoPatternCustom', ...
            '未检测到 patternCustom，跳过 Fig.400。该功能需要 Antenna Toolbox。');

        OverviewResult.PatternCustomGenerated = false;

        if ishandle(Fig400)
            close(Fig400);
        end
    end

catch ME
    warning('PlotPatternOverviewFigures:PatternCustomFailed', ...
        'Fig.400 patternCustom 绘制失败：%s', ME.message);

    OverviewResult.PatternCustomGenerated = false;

    if ishandle(Fig400)
        close(Fig400);
    end
end

end

%% ========================================================================
%  本地函数：ROI 统计
% =========================================================================
function RoiStats = AnalyzeRoiForPlotLocal(PhiGrid, ThetaGrid, GainGrid, ...
    PhiMin, PhiMax, ThetaMin, ThetaMax, ThresholdDb)

RoiMask = PhiGrid >= PhiMin & PhiGrid <= PhiMax & ...
          ThetaGrid >= ThetaMin & ThetaGrid <= ThetaMax & ...
          ~isnan(GainGrid);

GainValid = GainGrid(RoiMask);

if isempty(GainValid)
    error('PlotPatternOverviewFigures:EmptyRoi', 'ROI 内无有效数据。');
end

MaskedGain = GainGrid;
MaskedGain(~RoiMask) = NaN;

[GainMax, IdxMax] = max(MaskedGain(:));
[GainMin, IdxMin] = min(MaskedGain(:));

[RowMax, ColMax] = ind2sub(size(GainGrid), IdxMax);
[RowMin, ColMin] = ind2sub(size(GainGrid), IdxMin);

RoiStats = struct();

RoiStats.PhiMin   = PhiMin;
RoiStats.PhiMax   = PhiMax;
RoiStats.ThetaMin = ThetaMin;
RoiStats.ThetaMax = ThetaMax;

RoiStats.ThresholdDb = ThresholdDb;

RoiStats.GainMax    = GainMax;
RoiStats.GainMin    = GainMin;
RoiStats.GainMean   = mean(GainValid);
RoiStats.GainMedian = median(GainValid);
RoiStats.GainStd    = std(GainValid);
RoiStats.GainRange  = GainMax - GainMin;

RoiStats.PercentAboveThreshold = 100 * mean(GainValid > ThresholdDb);
RoiStats.NumValidPoints        = numel(GainValid);

RoiStats.PhiAtMax   = PhiGrid(RowMax, ColMax);
RoiStats.ThetaAtMax = ThetaGrid(RowMax, ColMax);
RoiStats.PhiAtMin   = PhiGrid(RowMin, ColMin);
RoiStats.ThetaAtMin = ThetaGrid(RowMin, ColMin);

fprintf('\n========== ROI 增益分析报告 ==========%s', newline);
fprintf('  ROI 范围 : phi [%.1f°, %.1f°]  theta [%.1f°, %.1f°]\n', ...
    PhiMin, PhiMax, ThetaMin, ThetaMax);
fprintf('  有效点数 : %d\n', RoiStats.NumValidPoints);
fprintf('  最大增益 : %+.3f dBi  @ phi=%.1f°, theta=%.1f°\n', ...
    RoiStats.GainMax, RoiStats.PhiAtMax, RoiStats.ThetaAtMax);
fprintf('  最小增益 : %+.3f dBi  @ phi=%.1f°, theta=%.1f°\n', ...
    RoiStats.GainMin, RoiStats.PhiAtMin, RoiStats.ThetaAtMin);
fprintf('  平均增益 : %+.3f dBi\n', RoiStats.GainMean);
fprintf('  中位增益 : %+.3f dBi\n', RoiStats.GainMedian);
fprintf('  标准差   : %.3f dB\n', RoiStats.GainStd);
fprintf('  峰峰差   : %.3f dB\n', RoiStats.GainRange);
fprintf('  Gain > %.3f dBi 比例 : %.2f %%\n', ...
    ThresholdDb, RoiStats.PercentAboveThreshold);
fprintf('=======================================%s%s', newline, newline);

end

%% ========================================================================
%  本地函数：在 Fig.200 上绘制 ROI
% =========================================================================
function DrawRoiOnAxesLocal(AxesHandle, RoiStats)

axes(AxesHandle);
hold on;

RoiX = [RoiStats.PhiMin, RoiStats.PhiMax, RoiStats.PhiMax, RoiStats.PhiMin, RoiStats.PhiMin];
RoiY = [RoiStats.ThetaMin, RoiStats.ThetaMin, RoiStats.ThetaMax, RoiStats.ThetaMax, RoiStats.ThetaMin];

plot(RoiX, RoiY, 'w--', ...
    'LineWidth', 2.0, ...
    'DisplayName', 'ROI 边界');

plot(RoiStats.PhiAtMax, RoiStats.ThetaAtMax, '^w', ...
    'MarkerSize', 10, ...
    'MarkerFaceColor', 'w', ...
    'LineWidth', 1.5, ...
    'DisplayName', sprintf('Max %.2f dBi', RoiStats.GainMax));

text(RoiStats.PhiAtMax, RoiStats.ThetaAtMax, ...
    sprintf('  Max %.2f dBi', RoiStats.GainMax), ...
    'Color', 'w', ...
    'FontSize', 8, ...
    'FontWeight', 'bold', ...
    'VerticalAlignment', 'bottom');

plot(RoiStats.PhiAtMin, RoiStats.ThetaAtMin, 'vy', ...
    'MarkerSize', 10, ...
    'MarkerFaceColor', 'y', ...
    'LineWidth', 1.5, ...
    'DisplayName', sprintf('Min %.2f dBi', RoiStats.GainMin));

text(RoiStats.PhiAtMin, RoiStats.ThetaAtMin, ...
    sprintf('  Min %.2f dBi', RoiStats.GainMin), ...
    'Color', 'y', ...
    'FontSize', 8, ...
    'FontWeight', 'bold', ...
    'VerticalAlignment', 'top');

legend('Location', 'best', ...
    'TextColor', 'w', ...
    'Color', [0.2 0.2 0.2]);

hold off;

end

%% ========================================================================
%  本地函数：保存图片
% =========================================================================
function SaveFigureLocal(FigureHandle, OutputPath)

ParentDir = fileparts(OutputPath);

if ~exist(ParentDir, 'dir')
    mkdir(ParentDir);
end

try
    exportgraphics(FigureHandle, OutputPath, 'Resolution', 200);
catch
    saveas(FigureHandle, OutputPath);
end

end