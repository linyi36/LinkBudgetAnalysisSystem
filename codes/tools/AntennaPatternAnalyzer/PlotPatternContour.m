function FigHandle = PlotPatternContour(Pattern, SavePath, FlagShowFigure)
% /*!
% * @brief 绘制 Phi/Theta/Gain 二维等高线图并保存 PNG。
% * @param[in] Pattern, struct, ReadAntennaPatternCsv 输出结构体。
% * @param[in] SavePath, char/string, PNG 保存路径。
% * @param[in] FlagShowFigure, logical, 是否显示图窗。
% * @param[out] FigHandle, figure handle。
% */

if nargin < 3
    FlagShowFigure = true;
end

FigVisible = 'on';
if ~FlagShowFigure
    FigVisible = 'off';
end

FigHandle = figure('Color', 'w', 'Visible', FigVisible);
contourf(Pattern.PhiGrid, Pattern.ThetaGrid, Pattern.GainGrid, 40, 'LineColor', 'none');
colorbar;
colormap(jet);
xlabel('Phi [deg]');
ylabel('Theta [deg]');
title(sprintf('%s: Phi / Theta / Gain', Pattern.FileBaseName), 'Interpreter', 'none');
grid on;

HoldState = ishold;
hold on;
PlotKeyDirectionMarkers(Pattern);
if ~HoldState
    hold off;
end

EnsureParentDir(SavePath);
saveas(FigHandle, SavePath);
end

function PlotKeyDirectionMarkers(Pattern)
ThetaMin = min(Pattern.ThetaUnique);
ThetaMax = max(Pattern.ThetaUnique);

if ThetaMin <= 0 && ThetaMax >= 180
    plot(90, 90, 'rx', 'LineWidth', 1.5, 'MarkerSize', 8);
    text(90, 90, ' tail', 'Color', 'r', 'FontWeight', 'bold');
    plot(270, 90, 'wx', 'LineWidth', 1.5, 'MarkerSize', 8);
    text(270, 90, ' head', 'Color', 'w', 'FontWeight', 'bold');
end
end

function EnsureParentDir(FilePath)
ParentDir = fileparts(FilePath);
if ~isempty(ParentDir) && ~exist(ParentDir, 'dir')
    mkdir(ParentDir);
end
end
