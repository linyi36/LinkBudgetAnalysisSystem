function OpenPatternSlider(Pattern)
% /*!
% * @brief Phi/Theta 滑块与手动输入交互界面。
% * @details 本函数基于已读取的方向图 Pattern，提供 Phi/Theta 滑块、手动输入框、
% *          查询按钮和方向图标记点。用户既可以拖动滑块，也可以手动输入角度，
% *          实时查询当前 Phi/Theta 方向对应的 Gain。
% * @param[in] Pattern, struct, 方向图结构体，需包含 PhiGrid、ThetaGrid、GainGrid。
% * @pre 已通过 ReadAntennaPatternCsv 读取方向图。
% * @bug Null
% * @warning 输入角度超出方向图范围时，会自动限制在合法范围内。
% * @author Lin Yi
% * @version 2.1
% * @date 2026.05.30
% * @copyright Null
% * @remark { revision history: 2026.05.30. V2.1, Lin Yi, add manual Phi/Theta input boxes. }
% */

%% 1. 输入检查
if nargin < 1 || isempty(Pattern)
    error('OpenPatternSlider 需要输入 Pattern。正确调用方式：OpenPatternSlider(Pattern)');
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

if PhiMin <= 90 && PhiMax >= 90 && ThetaMin <= 90 && ThetaMax >= 90
    PhiInit   = 90;
    ThetaInit = 90;
end

GainInit = QueryGainLocal(PhiGrid, ThetaGrid, GainGrid, PhiInit, ThetaInit);

%% 2. 创建界面
Fig = figure( ...
    'Name', 'Antenna Pattern Phi/Theta Query', ...
    'NumberTitle', 'off', ...
    'Color', 'w', ...
    'Position', [100, 100, 1100, 720]);

Ax = axes( ...
    'Parent', Fig, ...
    'Units', 'normalized', ...
    'Position', [0.08, 0.25, 0.62, 0.68]);

contourf(Ax, PhiGrid, ThetaGrid, GainGrid, 40, 'LineColor', 'none');
grid(Ax, 'on');
colorbar(Ax);
xlabel(Ax, 'Phi [deg]');
ylabel(Ax, 'Theta [deg]');
title(Ax, 'Phi / Theta / Gain 方向图查询');
hold(Ax, 'on');

MarkerHandle = plot(Ax, PhiInit, ThetaInit, 'rx', ...
    'LineWidth', 2.5, ...
    'MarkerSize', 12);

TextHandle = text(Ax, PhiInit, ThetaInit, ...
    sprintf('  Phi=%.2f°, Theta=%.2f°, Gain=%.3f dBi', PhiInit, ThetaInit, GainInit), ...
    'Color', 'r', ...
    'FontWeight', 'bold', ...
    'BackgroundColor', 'w', ...
    'Margin', 3);

%% 3. 右侧信息面板
Panel = uipanel( ...
    'Parent', Fig, ...
    'Title', '方向查询', ...
    'FontWeight', 'bold', ...
    'Units', 'normalized', ...
    'Position', [0.73, 0.25, 0.24, 0.68]);

uicontrol(Panel, 'Style', 'text', ...
    'String', 'Phi [deg]', ...
    'Units', 'normalized', ...
    'HorizontalAlignment', 'left', ...
    'Position', [0.08, 0.88, 0.35, 0.06]);

PhiSlider = uicontrol(Panel, 'Style', 'slider', ...
    'Units', 'normalized', ...
    'Min', PhiMin, ...
    'Max', PhiMax, ...
    'Value', PhiInit, ...
    'Position', [0.08, 0.82, 0.84, 0.05]);

PhiEdit = uicontrol(Panel, 'Style', 'edit', ...
    'Units', 'normalized', ...
    'String', sprintf('%.2f', PhiInit), ...
    'Position', [0.08, 0.75, 0.84, 0.06]);

uicontrol(Panel, 'Style', 'text', ...
    'String', 'Theta [deg]', ...
    'Units', 'normalized', ...
    'HorizontalAlignment', 'left', ...
    'Position', [0.08, 0.65, 0.45, 0.06]);

ThetaSlider = uicontrol(Panel, 'Style', 'slider', ...
    'Units', 'normalized', ...
    'Min', ThetaMin, ...
    'Max', ThetaMax, ...
    'Value', ThetaInit, ...
    'Position', [0.08, 0.59, 0.84, 0.05]);

ThetaEdit = uicontrol(Panel, 'Style', 'edit', ...
    'Units', 'normalized', ...
    'String', sprintf('%.2f', ThetaInit), ...
    'Position', [0.08, 0.52, 0.84, 0.06]);

QueryButton = uicontrol(Panel, 'Style', 'pushbutton', ...
    'String', '手动输入后查询', ...
    'Units', 'normalized', ...
    'FontWeight', 'bold', ...
    'Position', [0.08, 0.42, 0.84, 0.07]);

TailButton = uicontrol(Panel, 'Style', 'pushbutton', ...
    'String', '弹尾 Phi=90 Theta=90', ...
    'Units', 'normalized', ...
    'Position', [0.08, 0.32, 0.84, 0.06]);

HeadButton = uicontrol(Panel, 'Style', 'pushbutton', ...
    'String', '弹头 Phi=270 Theta=90', ...
    'Units', 'normalized', ...
    'Position', [0.08, 0.24, 0.84, 0.06]);

TopButton = uicontrol(Panel, 'Style', 'pushbutton', ...
    'String', 'Z轴/天顶 Theta=0', ...
    'Units', 'normalized', ...
    'Position', [0.08, 0.16, 0.84, 0.06]);

GainText = uicontrol(Panel, 'Style', 'text', ...
    'Units', 'normalized', ...
    'HorizontalAlignment', 'left', ...
    'FontSize', 11, ...
    'FontWeight', 'bold', ...
    'String', sprintf('当前 Gain = %.3f dBi', GainInit), ...
    'Position', [0.08, 0.07, 0.84, 0.06]);

uicontrol( ...
    'Parent', Fig, ...
    'Style', 'text', ...
    'Units', 'normalized', ...
    'HorizontalAlignment', 'left', ...
    'FontSize', 10, ...
    'String', sprintf('Phi范围: %.2f~%.2f deg    Theta范围: %.2f~%.2f deg    支持滑块拖动和手动输入', ...
        PhiMin, PhiMax, ThetaMin, ThetaMax), ...
    'Position', [0.08, 0.08, 0.89, 0.05], ...
    'BackgroundColor', 'w');

%% 4. 设置回调
set(PhiSlider, 'Callback', @OnSliderChanged);
set(ThetaSlider, 'Callback', @OnSliderChanged);
set(PhiEdit, 'Callback', @OnEditChanged);
set(ThetaEdit, 'Callback', @OnEditChanged);
set(QueryButton, 'Callback', @OnEditChanged);
set(TailButton, 'Callback', @(~,~) SetQueryPoint(90, 90));
set(HeadButton, 'Callback', @(~,~) SetQueryPoint(270, 90));
set(TopButton,  'Callback', @(~,~) SetQueryPoint(PhiInit, 0));

UpdateQuery(PhiInit, ThetaInit);

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

    function SetQueryPoint(PhiVal, ThetaVal)
        PhiVal   = ClampLocal(PhiVal, PhiMin, PhiMax);
        ThetaVal = ClampLocal(ThetaVal, ThetaMin, ThetaMax);

        set(PhiSlider, 'Value', PhiVal);
        set(ThetaSlider, 'Value', ThetaVal);
        set(PhiEdit, 'String', sprintf('%.2f', PhiVal));
        set(ThetaEdit, 'String', sprintf('%.2f', ThetaVal));

        UpdateQuery(PhiVal, ThetaVal);
    end

    function UpdateQuery(PhiVal, ThetaVal)
        GainVal = QueryGainLocal(PhiGrid, ThetaGrid, GainGrid, PhiVal, ThetaVal);

        set(MarkerHandle, 'XData', PhiVal, 'YData', ThetaVal);
        set(TextHandle, ...
            'Position', [PhiVal, ThetaVal, 0], ...
            'String', sprintf('  Phi=%.2f°, Theta=%.2f°, Gain=%.3f dBi', PhiVal, ThetaVal, GainVal));

        set(GainText, 'String', sprintf('当前 Gain = %.3f dBi', GainVal));
        title(Ax, sprintf('Phi=%.2f°, Theta=%.2f°, Gain=%.3f dBi', PhiVal, ThetaVal, GainVal));
        drawnow;
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
