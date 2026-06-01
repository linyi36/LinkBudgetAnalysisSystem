function CutResult = PlotPatternCuts(Pattern, FixedThetaListDeg, FixedPhiListDeg, ThresholdDb, OutputDir, FlagShowFigure)
% /*!
% * @brief 绘制一维切面图，支持多个固定 Phi/Theta 角度画到同一张图上。
% * @details 固定 Theta 时扫描 Phi；固定 Phi 时扫描 Theta。所有切面数据同时输出为 CSV。
% * @param[in] Pattern, struct, 方向图结构体。
% * @param[in] FixedThetaListDeg, 1xN double, 固定 Theta 列表，可为空。
% * @param[in] FixedPhiListDeg, 1xM double, 固定 Phi 列表，可为空。
% * @param[in] ThresholdDb, 1x1 double, 指标阈值，用于在图中画水平线。
% * @param[in] OutputDir, char/string, 输出目录。
% * @param[in] FlagShowFigure, logical, 是否显示图窗。
% * @param[out] CutResult, struct, 保存输出文件路径。
% */

if nargin < 6
    FlagShowFigure = true;
end
if nargin < 5 || isempty(OutputDir)
    OutputDir = pwd;
end
if ~exist(OutputDir, 'dir')
    mkdir(OutputDir);
end
if nargin < 4
    ThresholdDb = NaN;
end

CutResult = struct();
CutResult.ThetaCutPng = '';
CutResult.PhiCutPng   = '';
CutResult.CutCsv      = fullfile(OutputDir, [Pattern.FileBaseName, '_CutData.csv']);

CutTypeList = {};
FixedAngleList = [];
SweepAngleList = [];
GainList = [];

FigVisible = 'on';
if ~FlagShowFigure
    FigVisible = 'off';
end

%% 固定 Theta，扫描 Phi
if ~isempty(FixedThetaListDeg)
    FigTheta = figure('Color', 'w', 'Visible', FigVisible);
    hold on;
    for Idx = 1:numel(FixedThetaListDeg)
        TargetTheta = FixedThetaListDeg(Idx);
        [~, IdxTheta] = min(abs(Pattern.ThetaUnique - TargetTheta));
        ActualTheta = Pattern.ThetaUnique(IdxTheta);
        PhiSweep = Pattern.PhiUnique(:);
        GainCut = Pattern.GainGrid(IdxTheta, :).';
        plot(PhiSweep, GainCut, 'LineWidth', 1.5, ...
            'DisplayName', sprintf('Theta=%.2f°', ActualTheta));
        CutTypeList = [CutTypeList; repmat({'FixedTheta'}, numel(PhiSweep), 1)]; %#ok<AGROW>
        FixedAngleList = [FixedAngleList; repmat(ActualTheta, numel(PhiSweep), 1)]; %#ok<AGROW>
        SweepAngleList = [SweepAngleList; PhiSweep]; %#ok<AGROW>
        GainList = [GainList; GainCut]; %#ok<AGROW>
    end
    AddThresholdLine(ThresholdDb, Pattern.PhiUnique);
    xlabel('Phi [deg]');
    ylabel('Gain [dBi]');
    title(sprintf('%s: fixed Theta, scan Phi', Pattern.FileBaseName), 'Interpreter', 'none');
    legend('Location', 'best');
    grid on;
    hold off;
    CutResult.ThetaCutPng = fullfile(OutputDir, [Pattern.FileBaseName, '_FixedThetaScanPhi.png']);
    saveas(FigTheta, CutResult.ThetaCutPng);
end

%% 固定 Phi，扫描 Theta
if ~isempty(FixedPhiListDeg)
    FigPhi = figure('Color', 'w', 'Visible', FigVisible);
    hold on;
    for Idx = 1:numel(FixedPhiListDeg)
        TargetPhi = mod(FixedPhiListDeg(Idx), 360);
        [~, IdxPhi] = min(abs(WrapTo180Local(Pattern.PhiUnique - TargetPhi)));
        ActualPhi = Pattern.PhiUnique(IdxPhi);
        ThetaSweep = Pattern.ThetaUnique(:);
        GainCut = Pattern.GainGrid(:, IdxPhi);
        plot(ThetaSweep, GainCut, 'LineWidth', 1.5, ...
            'DisplayName', sprintf('Phi=%.2f°', ActualPhi));
        CutTypeList = [CutTypeList; repmat({'FixedPhi'}, numel(ThetaSweep), 1)]; %#ok<AGROW>
        FixedAngleList = [FixedAngleList; repmat(ActualPhi, numel(ThetaSweep), 1)]; %#ok<AGROW>
        SweepAngleList = [SweepAngleList; ThetaSweep]; %#ok<AGROW>
        GainList = [GainList; GainCut]; %#ok<AGROW>
    end
    AddThresholdLine(ThresholdDb, Pattern.ThetaUnique);
    xlabel('Theta [deg]');
    ylabel('Gain [dBi]');
    title(sprintf('%s: fixed Phi, scan Theta', Pattern.FileBaseName), 'Interpreter', 'none');
    legend('Location', 'best');
    grid on;
    hold off;
    CutResult.PhiCutPng = fullfile(OutputDir, [Pattern.FileBaseName, '_FixedPhiScanTheta.png']);
    saveas(FigPhi, CutResult.PhiCutPng);
end

if ~isempty(GainList)
    CutTable = table(CutTypeList, FixedAngleList, SweepAngleList, GainList, ...
        'VariableNames', {'CutType', 'FixedAngleDeg', 'SweepAngleDeg', 'GainDb'});
    writetable(CutTable, CutResult.CutCsv);
end
end

function AddThresholdLine(ThresholdDb, XVec)
if ~isnan(ThresholdDb)
    XMin = min(XVec);
    XMax = max(XVec);
    plot([XMin, XMax], [ThresholdDb, ThresholdDb], 'k--', 'LineWidth', 1.2, ...
        'DisplayName', sprintf('Threshold %.2f dBi', ThresholdDb));
end
end

function AngleOut = WrapTo180Local(AngleIn)
AngleOut = mod(AngleIn + 180, 360) - 180;
end
