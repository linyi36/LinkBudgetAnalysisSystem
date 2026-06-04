function OpenPatternSlider(Pattern, Cfg)
% /*!
% * @brief Phi/Theta 滑块、手动输入、视图切换和 ROI 区域统计交互界面。
% * @details 本函数基于已读取的方向图 Pattern，提供 Phi/Theta 滑块、手动输入框、
% *          伪彩色/等高线图切换复选框，并在界面右下角提供 ROI 区域分析框，
% *          用于显示用户选定区域内统计结果。
% * @param[in] Pattern, struct, 方向图结构体，需包含 PhiGrid、ThetaGrid、GainGrid。
% * @param[in] Cfg, struct, 可选配置，包含 PhiRangeDeg、ThetaRangeDeg、GainThresholdDb。
% * @pre 已通过 ReadAntennaPatternCsv 读取方向图。
% * @bug Null
% * @warning 输入角度超出方向图范围时，会自动限制在合法范围内。
% * @author Lin Yi
% * @version 2.3
% * @date 2026.05.30
% * @copyright Null
% * @remark { revision history:
% *   2026.05.30. V2.1, Lin Yi, add manual Phi/Theta input boxes.
% *   2026.05.30. V2.2, Lin Yi, add view mode switch and ROI analysis panel.
% *   2026.05.30. V2.3, Lin Yi, remove fixed head/tail shortcut buttons.
% * }
% */

%% 1. 输入检查
if nargin < 1 || isempty(Pattern)
    error('OpenPatternSlider 需要输入 Pattern。正确调用方式：OpenPatternSlider(Pattern)');
end

if nargin < 2 || isempty(Cfg)
    Cfg = struct();
end

RequiredFields = {'PhiGrid', 'ThetaGrid', 'GainGrid'};
for IdxField = 1:numel(RequiredFields)
    if ~isfield(Pattern, RequiredFields{IdxField})
        error('Pattern 缺少字段：%s', RequiredFields{IdxField});
    end
end

PhiGrid   = Pattern.PhiGrid;
ThetaGrid = Pattern.ThetaGrid;
GainGrid  = Pattern.GainGrid;

PhiMin   = min(PhiGrid(:));
PhiMax   = max(PhiGrid(:));
ThetaMin = min(ThetaGrid(:));
ThetaMax = max(ThetaGrid(:));

PhiInit   = 0.5 * (PhiMin + PhiMax);
ThetaInit = 0.5 * (ThetaMin + ThetaMax);

% 默认查询点：如果方向图包含 Phi=90, Theta=90，则默认落在该点附近
if PhiMin <= 90 && PhiMax >= 90 && ThetaMin <= 90 && ThetaMax >= 90
    PhiInit   = 90;
    ThetaInit = 90;
end

GainInit = QueryGainLocal(PhiGrid, ThetaGrid, GainGrid, PhiInit, ThetaInit);

RoiPhiRange = GetCfgFieldLocal(Cfg, 'PhiRangeDeg', ...
    [max(PhiMin, PhiInit - 15), min(PhiMax, PhiInit + 15)]);

RoiThetaRange = GetCfgFieldLocal(Cfg, 'ThetaRangeDeg', ...
    [max(ThetaMin, ThetaInit - 15), min(ThetaMax, ThetaInit + 15)]);

RoiThreshold = GetCfgFieldLocal(Cfg, 'GainThresholdDb', -5);

%% 2. 创建界面
Fig = figure( ...
    'Name', 'Antenna Pattern Phi/Theta Query and ROI Analysis', ...
    'NumberTitle', 'off', ...
    'Color', 'w', ...
    'Position', [80, 80, 1280, 760]);

Ax = axes( ...
    'Parent', Fig, ...
    'Units', 'normalized', ...
    'Position', [0.06, 0.23, 0.62, 0.70]);

%% 3. 右侧方向查询面板
Panel = uipanel( ...
    'Parent', Fig, ...
    'Title', '方向查询', ...
    'FontWeight', 'bold', ...
    'Units', 'normalized', ...
    'Position', [0.71, 0.55, 0.26, 0.38]);

ViewModeCheckbox = uicontrol(Panel, 'Style', 'checkbox', ...
    'String', '伪彩色图模式 pcolor', ...
    'Units', 'normalized', ...
    'Value', 0, ...
    'HorizontalAlignment', 'left', ...
    'Position', [0.08, 0.89, 0.84, 0.08]);

uicontrol(Panel, 'Style', 'text', ...
    'String', 'Phi [deg]', ...
    'Units', 'normalized', ...
    'HorizontalAlignment', 'left', ...
    'Position', [0.08, 0.78, 0.35, 0.06]);

PhiSlider = uicontrol(Panel, 'Style', 'slider', ...
    'Units', 'normalized', ...
    'Min', PhiMin, ...
    'Max', PhiMax, ...
    'Value', PhiInit, ...
    'Position', [0.08, 0.72, 0.84, 0.05]);

PhiEdit = uicontrol(Panel, 'Style', 'edit', ...
    'Units', 'normalized', ...
    'String', sprintf('%.2f', PhiInit), ...
    'Position', [0.08, 0.65, 0.84, 0.06]);

uicontrol(Panel, 'Style', 'text', ...
    'String', 'Theta [deg]', ...
    'Units', 'normalized', ...
    'HorizontalAlignment', 'left', ...
    'Position', [0.08, 0.55, 0.45, 0.06]);

ThetaSlider = uicontrol(Panel, 'Style', 'slider', ...
    'Units', 'normalized', ...
    'Min', ThetaMin, ...
    'Max', ThetaMax, ...
    'Value', ThetaInit, ...
    'Position', [0.08, 0.49, 0.84, 0.05]);

ThetaEdit = uicontrol(Panel, 'Style', 'edit', ...
    'Units', 'normalized', ...
    'String', sprintf('%.2f', ThetaInit), ...
    'Position', [0.08, 0.42, 0.84, 0.06]);

QueryButton = uicontrol(Panel, 'Style', 'pushbutton', ...
    'String', '手动输入后查询', ...
    'Units', 'normalized', ...
    'FontWeight', 'bold', ...
    'Position', [0.08, 0.30, 0.84, 0.08]);

GainText = uicontrol(Panel, 'Style', 'text', ...
    'Units', 'normalized', ...
    'HorizontalAlignment', 'left', ...
    'FontSize', 11, ...
    'FontWeight', 'bold', ...
    'String', sprintf('当前 Gain = %.3f dBi', GainInit), ...
    'Position', [0.08, 0.16, 0.84, 0.08]);

uicontrol(Panel, 'Style', 'text', ...
    'Units', 'normalized', ...
    'HorizontalAlignment', 'left', ...
    'FontSize', 9, ...
    'String', '说明：可拖动滑块，或手动输入 Phi / Theta 后查询。', ...
    'Position', [0.08, 0.05, 0.84, 0.08]);

%% 4. 右下角 ROI 区域分析框
RoiPanel = uipanel( ...
    'Parent', Fig, ...
    'Title', '区域分析 ROI', ...
    'FontWeight', 'bold', ...
    'Units', 'normalized', ...
    'Position', [0.71, 0.08, 0.26, 0.42]);

uicontrol(RoiPanel, 'Style', 'text', ...
    'String', 'Phi min / max', ...
    'Units', 'normalized', ...
    'HorizontalAlignment', 'left', ...
    'Position', [0.08, 0.86, 0.42, 0.06]);

RoiPhiMinEdit = uicontrol(RoiPanel, 'Style', 'edit', ...
    'Units', 'normalized', ...
    'String', sprintf('%.2f', RoiPhiRange(1)), ...
    'Position', [0.50, 0.86, 0.18, 0.06]);

RoiPhiMaxEdit = uicontrol(RoiPanel, 'Style', 'edit', ...
    'Units', 'normalized', ...
    'String', sprintf('%.2f', RoiPhiRange(2)), ...
    'Position', [0.72, 0.86, 0.18, 0.06]);

uicontrol(RoiPanel, 'Style', 'text', ...
    'String', 'Theta min / max', ...
    'Units', 'normalized', ...
    'HorizontalAlignment', 'left', ...
    'Position', [0.08, 0.77, 0.42, 0.06]);

RoiThetaMinEdit = uicontrol(RoiPanel, 'Style', 'edit', ...
    'Units', 'normalized', ...
    'String', sprintf('%.2f', RoiThetaRange(1)), ...
    'Position', [0.50, 0.77, 0.18, 0.06]);

RoiThetaMaxEdit = uicontrol(RoiPanel, 'Style', 'edit', ...
    'Units', 'normalized', ...
    'String', sprintf('%.2f', RoiThetaRange(2)), ...
    'Position', [0.72, 0.77, 0.18, 0.06]);

uicontrol(RoiPanel, 'Style', 'text', ...
    'String', 'Threshold [dBi]', ...
    'Units', 'normalized', ...
    'HorizontalAlignment', 'left', ...
    'Position', [0.08, 0.68, 0.42, 0.06]);

RoiThresholdEdit = uicontrol(RoiPanel, 'Style', 'edit', ...
    'Units', 'normalized', ...
    'String', sprintf('%.2f', RoiThreshold), ...
    'Position', [0.50, 0.68, 0.40, 0.06]);

RoiButton = uicontrol(RoiPanel, 'Style', 'pushbutton', ...
    'String', '更新区域统计', ...
    'Units', 'normalized', ...
    'FontWeight', 'bold', ...
    'Position', [0.08, 0.58, 0.82, 0.07]);

RoiResultText = uicontrol(RoiPanel, 'Style', 'text', ...
    'Units', 'normalized', ...
    'HorizontalAlignment', 'left', ...
    'FontName', 'Consolas', ...
    'FontSize', 9, ...
    'String', '', ...
    'Position', [0.08, 0.04, 0.84, 0.50]);

uicontrol( ...
    'Parent', Fig, ...
    'Style', 'text', ...
    'Units', 'normalized', ...
    'HorizontalAlignment', 'left', ...
    'FontSize', 10, ...
    'String', sprintf('Phi范围: %.2f~%.2f deg    Theta范围: %.2f~%.2f deg    支持滑块、手动输入、视图切换和 ROI 统计', ...
        PhiMin, PhiMax, ThetaMin, ThetaMax), ...
    'Position', [0.06, 0.08, 0.62, 0.05], ...
    'BackgroundColor', 'w');

%% 5. 图形对象句柄
MarkerHandle = [];
TextHandle   = [];
RoiHandles   = gobjects(0);

%% 6. 设置回调
set(PhiSlider, 'Callback', @OnSliderChanged);
set(ThetaSlider, 'Callback', @OnSliderChanged);
set(PhiEdit, 'Callback', @OnEditChanged);
set(ThetaEdit, 'Callback', @OnEditChanged);
set(QueryButton, 'Callback', @OnEditChanged);

set(ViewModeCheckbox, 'Callback', @OnViewModeChanged);

set(RoiButton, 'Callback', @OnRoiChanged);
set(RoiPhiMinEdit, 'Callback', @OnRoiChanged);
set(RoiPhiMaxEdit, 'Callback', @OnRoiChanged);
set(RoiThetaMinEdit, 'Callback', @OnRoiChanged);
set(RoiThetaMaxEdit, 'Callback', @OnRoiChanged);
set(RoiThresholdEdit, 'Callback', @OnRoiChanged);

DrawBaseMap();
UpdateQuery(PhiInit, ThetaInit);
UpdateRoiAnalysis();

%% ========================================================================
%  回调函数
% =========================================================================

    function OnSliderChanged(~, ~)
        PhiVal   = get(PhiSlider, 'Value');
        ThetaVal = get(ThetaSlider, 'Value');

        set(PhiEdit, 'String', sprintf('%.2f', PhiVal));
        set(ThetaEdit, 'String', sprintf('%.2f', ThetaVal));

        UpdateQuery(PhiVal, ThetaVal);
    end

    function OnEditChanged(~, ~)
        PhiVal = str2double(get(PhiEdit, 'String'));
        ThetaVal = str2double(get(ThetaEdit, 'String'));

        if isnan(PhiVal)
            warning('Phi 输入不是有效数字，已恢复为当前滑块值。');
            PhiVal = get(PhiSlider, 'Value');
        end

        if isnan(ThetaVal)
            warning('Theta 输入不是有效数字，已恢复为当前滑块值。');
            ThetaVal = get(ThetaSlider, 'Value');
        end

        PhiVal   = ClampLocal(PhiVal, PhiMin, PhiMax);
        ThetaVal = ClampLocal(ThetaVal, ThetaMin, ThetaMax);

        set(PhiSlider, 'Value', PhiVal);
        set(ThetaSlider, 'Value', ThetaVal);
        set(PhiEdit, 'String', sprintf('%.2f', PhiVal));
        set(ThetaEdit, 'String', sprintf('%.2f', ThetaVal));

        UpdateQuery(PhiVal, ThetaVal);
    end

    function OnViewModeChanged(~, ~)
        CurrentPhi   = get(PhiSlider, 'Value');
        CurrentTheta = get(ThetaSlider, 'Value');

        DrawBaseMap();
        UpdateQuery(CurrentPhi, CurrentTheta);
        UpdateRoiAnalysis();
    end

    function OnRoiChanged(~, ~)
        UpdateRoiAnalysis();
    end

    function DrawBaseMap()
        axes(Ax);
        cla(Ax);

        IsPseudoColor = get(ViewModeCheckbox, 'Value') > 0;

        if IsPseudoColor
            pcolor(Ax, PhiGrid, ThetaGrid, GainGrid);
            shading(Ax, 'interp');
            title(Ax, '伪彩色图 pcolor：Phi / Theta / Gain');
        else
            contourf(Ax, PhiGrid, ThetaGrid, GainGrid, 32, 'LineColor', 'none');
            hold(Ax, 'on');
            contour(Ax, PhiGrid, ThetaGrid, GainGrid, 32, ...
                'LineColor', [0.15 0.15 0.15], ...
                'LineStyle', '-', ...
                'LineWidth', 0.35);
            title(Ax, '等高线图 contourf + 实线 contour：Phi / Theta / Gain');
        end

        hold(Ax, 'on');
        grid(Ax, 'on');
        colorbar(Ax);
        colormap(Ax, jet);

        xlabel(Ax, 'Phi [deg]');
        ylabel(Ax, 'Theta [deg]');

        MarkerHandle = plot(Ax, NaN, NaN, 'rx', ...
            'LineWidth', 2.5, ...
            'MarkerSize', 12);

        TextHandle = text(Ax, NaN, NaN, '', ...
            'Color', 'r', ...
            'FontWeight', 'bold', ...
            'BackgroundColor', 'w', ...
            'Margin', 3);

        RoiHandles = gobjects(0);
    end

    function UpdateQuery(PhiVal, ThetaVal)
        GainVal = QueryGainLocal(PhiGrid, ThetaGrid, GainGrid, PhiVal, ThetaVal);

        set(MarkerHandle, 'XData', PhiVal, 'YData', ThetaVal);

        set(TextHandle, ...
            'Position', [PhiVal, ThetaVal, 0], ...
            'String', sprintf('  Phi=%.2f°, Theta=%.2f°, Gain=%.3f dBi', ...
                PhiVal, ThetaVal, GainVal));

        set(GainText, 'String', sprintf('当前 Gain = %.3f dBi', GainVal));

        drawnow;
    end

    function UpdateRoiAnalysis()
        PhiMinRoi     = ReadNumberLocal(RoiPhiMinEdit, RoiPhiRange(1));
        PhiMaxRoi     = ReadNumberLocal(RoiPhiMaxEdit, RoiPhiRange(2));
        ThetaMinRoi   = ReadNumberLocal(RoiThetaMinEdit, RoiThetaRange(1));
        ThetaMaxRoi   = ReadNumberLocal(RoiThetaMaxEdit, RoiThetaRange(2));
        ThresholdRoi  = ReadNumberLocal(RoiThresholdEdit, RoiThreshold);

        PhiMinRoi   = ClampLocal(PhiMinRoi, PhiMin, PhiMax);
        PhiMaxRoi   = ClampLocal(PhiMaxRoi, PhiMin, PhiMax);
        ThetaMinRoi = ClampLocal(ThetaMinRoi, ThetaMin, ThetaMax);
        ThetaMaxRoi = ClampLocal(ThetaMaxRoi, ThetaMin, ThetaMax);

        set(RoiPhiMinEdit, 'String', sprintf('%.2f', PhiMinRoi));
        set(RoiPhiMaxEdit, 'String', sprintf('%.2f', PhiMaxRoi));
        set(RoiThetaMinEdit, 'String', sprintf('%.2f', ThetaMinRoi));
        set(RoiThetaMaxEdit, 'String', sprintf('%.2f', ThetaMaxRoi));
        set(RoiThresholdEdit, 'String', sprintf('%.2f', ThresholdRoi));

        RoiStats = AnalyzeRoiLocal(PhiMinRoi, PhiMaxRoi, ThetaMinRoi, ThetaMaxRoi, ThresholdRoi);

        DeleteRoiHandles();
        DrawRoiStats(RoiStats);

        ResultString = sprintf([ ...
            'Points : %d\n', ...
            'Min    : %.3f dBi\n', ...
            'Mean   : %.3f dBi\n', ...
            'Max    : %.3f dBi\n', ...
            'Median : %.3f dBi\n', ...
            'Std    : %.3f dB\n', ...
            '> %.2f : %.2f %%\n', ...
            'Pass   : %d'], ...
            RoiStats.NumPoints, ...
            RoiStats.GainMin, ...
            RoiStats.GainMean, ...
            RoiStats.GainMax, ...
            RoiStats.GainMedian, ...
            RoiStats.GainStd, ...
            ThresholdRoi, ...
            RoiStats.PercentAbove, ...
            RoiStats.PassFlag);

        set(RoiResultText, 'String', ResultString);
    end

    function RoiStats = AnalyzeRoiLocal(PhiMinRoi, PhiMaxRoi, ThetaMinRoi, ThetaMaxRoi, ThresholdRoi)
        PhiLow    = min(PhiMinRoi, PhiMaxRoi);
        PhiHigh   = max(PhiMinRoi, PhiMaxRoi);
        ThetaLow  = min(ThetaMinRoi, ThetaMaxRoi);
        ThetaHigh = max(ThetaMinRoi, ThetaMaxRoi);

        RegionMask = PhiGrid >= PhiLow & PhiGrid <= PhiHigh & ...
                     ThetaGrid >= ThetaLow & ThetaGrid <= ThetaHigh & ...
                     ~isnan(GainGrid);

        ValidLinearIdx = find(RegionMask);
        GainValid = GainGrid(ValidLinearIdx);

        if isempty(GainValid)
            error('ROI 内无有效点，请检查 Phi / Theta 范围。');
        end

        [GainMax, RelMaxIdx] = max(GainValid);
        [GainMin, RelMinIdx] = min(GainValid);

        MaxLinearIdx = ValidLinearIdx(RelMaxIdx);
        MinLinearIdx = ValidLinearIdx(RelMinIdx);

        [RowMax, ColMax] = ind2sub(size(GainGrid), MaxLinearIdx);
        [RowMin, ColMin] = ind2sub(size(GainGrid), MinLinearIdx);

        RoiStats = struct();
        RoiStats.PhiMin       = PhiLow;
        RoiStats.PhiMax       = PhiHigh;
        RoiStats.ThetaMin     = ThetaLow;
        RoiStats.ThetaMax     = ThetaHigh;
        RoiStats.GainMin      = GainMin;
        RoiStats.GainMean     = mean(GainValid);
        RoiStats.GainMax      = GainMax;
        RoiStats.GainMedian   = median(GainValid);
        RoiStats.GainStd      = std(GainValid);
        RoiStats.PercentAbove = 100 * mean(GainValid > ThresholdRoi);
        RoiStats.PassFlag     = RoiStats.PercentAbove >= 100;
        RoiStats.NumPoints    = numel(GainValid);
        RoiStats.PhiAtMax     = PhiGrid(RowMax, ColMax);
        RoiStats.ThetaAtMax   = ThetaGrid(RowMax, ColMax);
        RoiStats.PhiAtMin     = PhiGrid(RowMin, ColMin);
        RoiStats.ThetaAtMin   = ThetaGrid(RowMin, ColMin);
    end

    function DrawRoiStats(RoiStats)
        axes(Ax);
        hold(Ax, 'on');

        RoiX = [RoiStats.PhiMin, RoiStats.PhiMax, RoiStats.PhiMax, RoiStats.PhiMin, RoiStats.PhiMin];
        RoiY = [RoiStats.ThetaMin, RoiStats.ThetaMin, RoiStats.ThetaMax, RoiStats.ThetaMax, RoiStats.ThetaMin];

        RoiHandles(end+1) = plot(Ax, RoiX, RoiY, 'w--', ...
            'LineWidth', 2.0);

        RoiHandles(end+1) = plot(Ax, RoiStats.PhiAtMax, RoiStats.ThetaAtMax, '^w', ...
            'MarkerSize', 9, ...
            'MarkerFaceColor', 'w', ...
            'LineWidth', 1.2);

        RoiHandles(end+1) = text(Ax, RoiStats.PhiAtMax, RoiStats.ThetaAtMax, ...
            sprintf('  Max %.2f', RoiStats.GainMax), ...
            'Color', 'w', ...
            'FontSize', 8, ...
            'FontWeight', 'bold');

        RoiHandles(end+1) = plot(Ax, RoiStats.PhiAtMin, RoiStats.ThetaAtMin, 'vy', ...
            'MarkerSize', 9, ...
            'MarkerFaceColor', 'y', ...
            'LineWidth', 1.2);

        RoiHandles(end+1) = text(Ax, RoiStats.PhiAtMin, RoiStats.ThetaAtMin, ...
            sprintf('  Min %.2f', RoiStats.GainMin), ...
            'Color', 'y', ...
            'FontSize', 8, ...
            'FontWeight', 'bold');

        hold(Ax, 'on');
    end

    function DeleteRoiHandles()
        if ~isempty(RoiHandles)
            for IdxHandle = 1:numel(RoiHandles)
                if isgraphics(RoiHandles(IdxHandle))
                    delete(RoiHandles(IdxHandle));
                end
            end
        end

        RoiHandles = gobjects(0);
    end

end

%% ========================================================================
%  局部工具函数
% =========================================================================

function GainVal = QueryGainLocal(PhiGrid, ThetaGrid, GainGrid, PhiVal, ThetaVal)
GainVal = interp2(PhiGrid, ThetaGrid, GainGrid, PhiVal, ThetaVal, 'linear', NaN);

if isnan(GainVal)
    GainVal = interp2(PhiGrid, ThetaGrid, GainGrid, PhiVal, ThetaVal, 'nearest', NaN);
end
end

function X = ClampLocal(X, XMin, XMax)
X = max(XMin, min(XMax, X));
end

function Value = ReadNumberLocal(EditHandle, DefaultValue)
Value = str2double(get(EditHandle, 'String'));

if isnan(Value)
    Value = DefaultValue;
end
end

function Value = GetCfgFieldLocal(Cfg, FieldName, DefaultValue)
if isstruct(Cfg) && isfield(Cfg, FieldName)
    Value = Cfg.(FieldName);
else
    Value = DefaultValue;
end
end