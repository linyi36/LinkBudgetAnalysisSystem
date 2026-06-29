function AntennaUnifiedTool
%% ========================================================================
% 函数名称: AntennaUnifiedTool
% 版本信息: 终极完全版 (GUI + CLI 双模式)
% 创 建 人: linyi & gemini
% 创建日期: 2026/06/28
%
% 功能描述:
%   基于 MATLAB Antenna Toolbox 的天线仿真与方向图生成综合工具。
%   支持 10 种经典天线，涵盖：3D/2D方向图、S11回波损耗、表面电流分布计算。
%   提供【可视化 GUI 模式】与【快捷脚本 CLI 模式】双模式无缝切换。
%
% 输    入:
%   [GUI 模式]: 无需代码传参。由用户在 UI 界面交互式输入以下参数：
%       1. antType  - 天线类型（支持10种经典天线，切换时自动推荐工作频率）
%       2. Freq_GHz - 中心工作频率 (GHz)
%       3. er       - 基板相对介电常数 (如 FR4 = 4.4，仅在天线支持时生效)
%       4. h_sub    - 基板厚度 (mm，仅在天线支持时生效)
%   [CLI 模式]: 无需外部传参。通过修改 runScript() 内部顶部的变量区配置：
%       - 对应变量: Freq_GHz, antType, er, h_sub
%
% 输    出:
%   1. 图形窗口 (Figures):
%       - Figure 1: 天线三维几何模型 (左下角内嵌物理尺寸与科普属性面板)
%       - Figure 2: 全空间 3D 辐射方向图 (Realized Gain，附带坐标轴角度说明)
%       - Figure 3: 二维切面极坐标图 (水平面 Azimuth + 垂直面 Elevation)
%       - Figure 4: S11 回波损耗曲线图 (宽带扫频阻抗匹配分析)
%       - Figure 5: 天线表面电流分布图 (热力图展示电磁波流动状态)
%   2. 本地文件 (File Export):
%       - 导出全空间扫掠数据 CSV 文件 (严格匹配 CST/HFSS 表头格式)
%       - 自动定位并保存至工程根目录下的 `codes/output` 文件夹中
%
% 修复/更新记录:
%   - [Fix] 重构 CSV 文件命名逻辑，自动提取天线类型与频率 (如 Patch_4.95GHz_GUI_153022.csv)，完美解决文件难以区分的问题。
%   - [Fix] 将输出 CSV 的表头严格重构为 Freq [GHz], Phi [deg], Theta [deg], dB(RealizedGainTotal)
%   - [Fix] 移除全局 try-catch 高度赋值，精准控制仅对 Patch 和 PIFA 生效。
%   - [Fix] 增加安全检查显式调用 antObj，彻底堵住代码分析器的未使用变量警告。
%   - [Update] 将天线物理属性与专家科普直接以内嵌悬浮面板的形式绘制在3D模型图中。
%   - [Update] 智能频率推荐：切换天线类型时，自动将频率重置为该天线的“甜点”频率。
%% ========================================================================
clc; close all;

% 弹出对话框让用户选择运行模式
choice = questdlg('请选择天线仿真工具的运行模式：', ...
    '启动模式选择', ...
    '启动可视化GUI', '运行快捷脚本(CLI)', '启动可视化GUI');

% 根据用户选择进入不同分支
switch choice
    case '启动可视化GUI'
        runGUI();
    case '运行快捷脚本(CLI)'
        runScript();
    otherwise
        disp('已取消运行。');
end
end

%% ========================================================================
% ======================= 模式1：可视化 GUI 模式 ==========================
% ========================================================================
function runGUI()
    %% 创建主GUI窗口
    fig = uifigure('Name','天线综合仿真工作站 ','Position',[100,100,900,600]);

    %% 左侧参数控制面板
    panel = uipanel(fig,'Position',[20,20,280,560],'Title','参数设置');
    
    % 1.天线类型下拉框
    uilabel(panel,'Position',[20,500,80,22],'Text','天线类型');
    antDrop = uidropdown(panel,'Position',[110,500,140,22],...
        'Items',{'1.偶极子(Dipole)','2.单极子(Monopole)','3.微带贴片(Patch)', ...
                 '4.八木天线(Yagi-Uda)','5.喇叭天线(Horn)','6.圆形环(Loop)', ...
                 '7.螺旋天线(Helix)','8.倒F天线(PIFA)','9.阿基米德螺旋(Spiral)', ...
                 '10.双锥天线(Bicone)'});

    % 2.工作频率(GHz)输入框
    uilabel(panel,'Position',[20,460,80,22],'Text','频率(GHz)');
    freqEdit = uieditfield(panel,'numeric','Position',[110,460,140,22],'Value',1.0);

    % 当选择不同天线时，自动推荐最优经典工作频率
    antDrop.ValueChangedFcn = @(~,~)updateDefaultFreq;
        function updateDefaultFreq
            switch antDrop.Value
                case '1.偶极子(Dipole)', freqEdit.Value = 1.0;     
                case '2.单极子(Monopole)', freqEdit.Value = 1.0;   
                case '3.微带贴片(Patch)', freqEdit.Value = 4.95;   
                case '4.八木天线(Yagi-Uda)', freqEdit.Value = 0.3; 
                case '5.喇叭天线(Horn)', freqEdit.Value = 10.0;    
                case '6.圆形环(Loop)', freqEdit.Value = 0.3;       
                case '7.螺旋天线(Helix)', freqEdit.Value = 2.4;    
                case '8.倒F天线(PIFA)', freqEdit.Value = 2.4;      
                case '9.阿基米德螺旋(Spiral)', freqEdit.Value = 2.0; 
                case '10.双锥天线(Bicone)', freqEdit.Value = 0.3;   
            end
        end

    % 3.基板相对介电常数
    uilabel(panel,'Position',[20,420,80,22],'Text','介电常数Er');
    erEdit = uieditfield(panel,'numeric','Position',[110,420,140,22],'Value',4.4);

    % 4.基板厚度(mm)
    uilabel(panel,'Position',[20,380,80,22],'Text','基板厚(mm)');
    hEdit = uieditfield(panel,'numeric','Position',[110,380,140,22],'Value',1.6);

    %% 功能操作按钮
    btnDesign   = uibutton(panel,'Position',[40,320,200,30],'Text','1. 生成天线几何模型');
    btnPattern3D= uibutton(panel,'Position',[40,270,200,30],'Text','2. 绘制 3D 辐射方向图');
    btnPattern2D= uibutton(panel,'Position',[40,220,200,30],'Text','3. 绘制 2D 切面极坐标图');
    btnExport   = uibutton(panel,'Position',[40,170,200,30],'Text','4. 导出 CSV 全空间数据');
    btnS11      = uibutton(panel,'Position',[40,120,200,30],'Text','5. 计算 S11 回波损耗曲线');
    btnCurrent  = uibutton(panel,'Position',[40,70, 200,30],'Text','6. 查看表面电流分布');

    %% 全局缓存天线对象、频率
    ant = [];
    freqHz = 0;

    %%==================== 回调1：生成并设计天线 ====================
    btnDesign.ButtonPushedFcn = @(~,~)designAnt;
        function designAnt
            sel = antDrop.Value;
            fGHz = freqEdit.Value;
            Er = erEdit.Value;
            hmm = hEdit.Value;
            freqHz = fGHz * 1e9;
            h = hmm * 1e-3; 
            
            % 实例化对应天线
            switch sel
                case '1.偶极子(Dipole)', ant = dipole;
                case '2.单极子(Monopole)', ant = monopole;
                case '3.微带贴片(Patch)', ant = patchMicrostrip;
                case '4.八木天线(Yagi-Uda)', ant = yagiUda;
                case '5.喇叭天线(Horn)', ant = horn;
                case '6.圆形环(Loop)', ant = loopCircular;
                case '7.螺旋天线(Helix)', ant = helix;
                case '8.倒F天线(PIFA)', ant = pifa;
                case '9.阿基米德螺旋(Spiral)', ant = spiralArchimedean;
                case '10.双锥天线(Bicone)', ant = bicone; 
            end
            
            % 【精准修复】：仅为贴片和PIFA赋予基板材料
            if contains(sel, 'Patch') || contains(sel, 'PIFA')
                d = dielectric('FR4'); d.EpsilonR = Er; d.Thickness = h;
                ant.Substrate = d; 
            end
            
            ant = design(ant, freqHz);
            
            % 【精准修复】：仅为贴片和PIFA修正厚度（避免破坏单极子等天线的高度）
            if contains(sel, 'Patch') || contains(sel, 'PIFA')
                ant.Height = h;
            end
            
            f1 = figure('Name','天线三维几何模型与属性面板'); show(ant); rotate3d(f1, 'on'); 
            
            % 在3D图上悬浮显示属性与科普
            overlayAntennaInfo(f1, ant, sel);
            
            disp("==================== GUI: 天线模型生成完成 ====================");
            disp("（注：天线属性与科普贴士已直接展示在三维几何图窗内）");
        end

    %%==================== 回调2：绘制3D辐射方向图 ====================
    btnPattern3D.ButtonPushedFcn = @(~,~)draw3D;
        function draw3D
            if isempty(ant), uialert(fig,"请先点击【生成天线模型】！","操作提示"); return; end
            d = uiprogressdlg(fig,'Title','计算中','Message','正在求解电磁矩阵...','Indeterminate','on');
            f2 = figure('Name','3D辐射方向图 (三维空间增益)');
            pattern(ant, freqHz);
            title({'3D 辐射方向图 (实际增益 Realized Gain)', 'Z轴: 天顶 (俯仰角 θ=0°), X轴: 正北 (方位角 φ=0°)'});
            rotate3d(f2, 'on'); close(d);
        end

    %%==================== 回调3：绘制2D水平/垂直切面 ====================
    btnPattern2D.ButtonPushedFcn = @(~,~)draw2D;
        function draw2D
            if isempty(ant), uialert(fig,"请先点击【生成天线模型】！","操作提示"); return; end
            d = uiprogressdlg(fig,'Title','计算中','Message','正在生成切面...','Indeterminate','on');
            figure('Name','二维切面辐射极坐标图');
            subplot(1,2,1); patternAzimuth(ant, freqHz); title({'水平面方向图', 'Azimuth (方位角/偏航角 \phi)'});
            subplot(1,2,2); patternElevation(ant, freqHz); title({'垂直面方向图', 'Elevation (俯仰角 \theta)'});
            close(d);
        end

    %%==================== 回调4：导出CSV增益数据 (精准命名+标准化表头) ====================
    btnExport.ButtonPushedFcn = @(~,~)exportData;
        function exportData
            if isempty(ant), uialert(fig,"请先点击【生成天线模型】！","操作提示"); return; end
            d = uiprogressdlg(fig,'Title','导出中','Message','生成CSV数据...','Indeterminate','on');
            
            [gain, th, ph] = pattern(ant, freqHz); 
            [Phi, Theta] = meshgrid(ph, th); 
            
            % 构建包含 Freq [GHz] 的标准数组
            freq_array = repmat(freqHz / 1e9, numel(gain), 1);
            
            % 利用 Table 重构表头，使其与 CST/HFSS 原生格式完全一致
            T = table(freq_array, Phi(:), Theta(:), gain(:));
            T.Properties.VariableNames = {'Freq [GHz]', 'Phi [deg]', 'Theta [deg]', 'dB(RealizedGainTotal)'};
            
            % 智能提取天线英文名称，用于生成文件名 (例如从 "3.微带贴片(Patch)" 中提取 "Patch")
            antToken = regexp(antDrop.Value, '\((.*?)\)', 'tokens', 'once');
            if ~isempty(antToken)
                antNameStr = antToken{1};
            else
                antNameStr = 'Antenna';
            end
            
            currentPath = fileparts(mfilename('fullpath'));
            outDir = fullfile(currentPath, '..', 'output');
            if ~exist(outDir, 'dir'), mkdir(outDir); end
            
            % 组合出专业的文件名：天线名_频率_模式_时间戳.csv
            fileName = sprintf('%s_%.2fGHz_GUI_%s.csv', antNameStr, freqEdit.Value, datestr(now, 'HHMMSS'));
            savePath = fullfile(outDir, fileName);
            writetable(T, savePath);
            
            close(d); uialert(fig, sprintf("导出成功！\n数据已保存至:\n%s", savePath), "完成");
        end

    %%==================== 回调5：计算 S11 回波损耗 ====================
    btnS11.ButtonPushedFcn = @(~,~)drawS11;
        function drawS11
            if isempty(ant), uialert(fig,"请先点击【生成天线模型】！","操作提示"); return; end
            d = uiprogressdlg(fig,'Title','计算中','Message','正在进行多频点扫频计算，耗时较长请耐心等待...','Indeterminate','on');
            f_sweep = linspace(freqHz*0.85, freqHz*1.15, 21);
            figure('Name','阻抗匹配: S11 回波损耗');
            returnLoss(ant, f_sweep);
            title('S_{11} 回波损耗 (小于 -10dB 说明匹配良好)');
            grid on; close(d);
        end

    %%==================== 回调6：表面电流分布 ====================
    btnCurrent.ButtonPushedFcn = @(~,~)drawCurrent;
        function drawCurrent
            if isempty(ant), uialert(fig,"请先点击【生成天线模型】！","操作提示"); return; end
            d = uiprogressdlg(fig,'Title','计算中','Message','正在计算表面电流...','Indeterminate','on');
            f3 = figure('Name','天线表面电流分布');
            current(ant, freqHz);
            title('天线表面电流分布 (红色代表电流强，蓝色代表弱)');
            rotate3d(f3, 'on'); close(d);
        end
end

%% ========================================================================
% ======================= 模式2：纯代码脚本模式 ===========================
% ========================================================================
function runScript()
    % ====== 手动输入参数配置区 ======
    Freq_GHz = 2.4; 
    antType = "8.倒F天线(PIFA)"; 
    er = 4.4; h_sub = 1.6e-3;
    % ================================

    disp("启动脚本模式，正在进行自动化仿真计算...");
    freqHz = Freq_GHz * 1e9;

    switch antType
        case "1.偶极子(Dipole)", ant = dipole;
        case "2.单极子(Monopole)", ant = monopole;
        case "3.微带贴片(Patch)", ant = patchMicrostrip;
        case "4.八木天线(Yagi-Uda)", ant = yagiUda;
        case "5.喇叭天线(Horn)", ant = horn;
        case "6.圆形环(Loop)", ant = loopCircular;
        case "7.螺旋天线(Helix)", ant = helix;
        case "8.倒F天线(PIFA)", ant = pifa;
        case "9.阿基米德螺旋(Spiral)", ant = spiralArchimedean;
        case "10.双锥天线(Bicone)", ant = bicone;
    end
    
    % 【精准修复】：仅为贴片和PIFA赋予基板材料
    if contains(antType, 'Patch') || contains(antType, 'PIFA')
        d = dielectric('FR4'); d.EpsilonR = er; d.Thickness = h_sub;
        ant.Substrate = d;
    end
    
    ant = design(ant, freqHz); 
    
    % 【精准修复】：仅为贴片和PIFA修正厚度
    if contains(antType, 'Patch') || contains(antType, 'PIFA')
        ant.Height = h_sub;
    end

    f1 = figure('Name','天线三维几何模型与属性面板'); show(ant); rotate3d(f1, 'on');
    
    % 在3D图上悬浮显示属性与科普
    overlayAntennaInfo(f1, ant, antType);
    disp("==================== 天线模型生成完成 ====================");
    disp("（注：天线属性与科普贴士已直接展示在三维几何图窗内）");

    disp("正在计算3D辐射方向图...");
    f2 = figure('Name','3D辐射方向图(实际增益 realized gain / dB)');
    pattern(ant, freqHz); title({'3D 辐射方向图', 'Z轴: 天顶 (θ=0°), X轴: 正北 (φ=0°)'}); rotate3d(f2, 'on');

    disp("正在计算2D辐射方向图...");
    figure('Name','2D切面辐射方向图');
    subplot(1,2,1); patternAzimuth(ant, freqHz); title({'水平面', 'Azimuth (\phi)'});
    subplot(1,2,2); patternElevation(ant, freqHz); title({'垂直面', 'Elevation (\theta)'});

    disp("正在计算 S11 回波损耗与表面电流...");
    figure('Name','S11 回波损耗'); returnLoss(ant, linspace(freqHz*0.85, freqHz*1.15, 21)); grid on;
    f3 = figure('Name','表面电流'); current(ant, freqHz); rotate3d(f3, 'on');

    disp("正在生成数据并导出标准CSV...");
    [gain, theta, phi] = pattern(ant, freqHz);
    [Phi, Theta] = meshgrid(phi, theta);
    
    % 重构标准表头输出
    freq_array = repmat(Freq_GHz, numel(gain), 1);
    T = table(freq_array, Phi(:), Theta(:), gain(:));
    T.Properties.VariableNames = {'Freq [GHz]', 'Phi [deg]', 'Theta [deg]', 'dB(RealizedGainTotal)'};
    
    % 智能提取天线英文名称，用于生成区分度高的文件名
    antToken = regexp(antType, '\((.*?)\)', 'tokens', 'once');
    if ~isempty(antToken)
        antNameStr = string(antToken{1});
    else
        antNameStr = "Antenna";
    end
    
    currentPath = fileparts(mfilename('fullpath'));
    outDir = fullfile(currentPath, '..', 'output');
    if ~exist(outDir, 'dir'), mkdir(outDir); end
    
    % 组合出专业的文件名：天线名_频率_Script.csv
    fileName = sprintf('%s_%.2fGHz_Script.csv', antNameStr, Freq_GHz);
    savePath = fullfile(outDir, fileName);
    writetable(T, savePath);
    disp(['导出完成！文件已保存至：', savePath]);
end

%% ========================================================================
% ================== 辅助函数：将信息渲染并悬浮到图窗中 ===================
% ========================================================================
function overlayAntennaInfo(figHandle, antObj, antName)
    % 显式安全检查，不仅保护程序不崩溃，也完美消除代码分析器的“未使用变量”警告
    if isempty(antObj)
        return;
    end

    % 1. 获取科普贴士
    tipCell = {'【科普小贴士】'};
    switch antName
        case '1.偶极子(Dipole)'
            tipCell(end+1:end+2) = {'推荐频率：0.3 ~ 3 GHz', '辐射原理：最经典的线天线，辐射如横放的甜甜圈。'};
        case '2.单极子(Monopole)'
            tipCell(end+1:end+2) = {'推荐频率：0.3 ~ 3 GHz', '辐射原理：利用地面镜像效应，水平面全向辐射。'};
        case '3.微带贴片(Patch)'
            tipCell(end+1:end+2) = {'推荐频率：2.4 ~ 10 GHz', '辐射原理：集中在缝隙中辐射，方向性强(单向)。'};
        case '4.八木天线(Yagi-Uda)'
            tipCell(end+1:end+2) = {'推荐频率：0.1 ~ 1 GHz', '辐射原理：利用寄生单元相位差，极度压缩向前辐射。'};
        case '5.喇叭天线(Horn)'
            tipCell(end+1:end+2) = {'推荐频率：5 ~ 20 GHz', '辐射原理：波导张开平滑过渡至自由空间，极高增益。'};
        case '6.圆形环(Loop)'
            tipCell(end+1:end+2) = {'推荐频率：0.01 ~ 0.5 GHz', '辐射原理：对磁场极度敏感，可视为磁偶极子。'};
        case '7.螺旋天线(Helix)'
            tipCell(end+1:end+2) = {'推荐频率：1.5 ~ 5 GHz', '辐射原理：发射圆极化波，抗电离层极化偏转。'};
        case '8.倒F天线(PIFA)'
            tipCell(end+1:end+2) = {'推荐频率：0.9 ~ 5 GHz', '辐射原理：短路引脚缩小体积，易与设备外壳共形。'};
        case '9.阿基米德螺旋(Spiral)'
            tipCell(end+1:end+2) = {'推荐频率：1 ~ 10 GHz', '辐射原理：半径渐变，实现超宽带谐振。'};
        case '10.双锥天线(Bicone)'
            tipCell(end+1:end+2) = {'推荐频率：0.1 ~ 1 GHz', '辐射原理：加粗版偶极子，锥体极大拓宽工作带宽。'};
    end
    
    % 2. 使用 evalc 拦截命令行输出获取物理属性
    propsText = evalc('disp(antObj)'); 
    propsText = regexprep(propsText, '<[^>]*>', ''); 
    propsText = strtrim(propsText);
    propCell = strsplit(propsText, '\n')';
    
    % 3. 组合最终文本（使用 (:) 强制全部转为列向量后拼接）
    displayText = [tipCell(:); {' '}; {'物理尺寸与属性 (m)'}; propCell(:)];
    
    % 4. 在图窗左下角绘制悬浮框
    annotation(figHandle, 'textbox', [0.02, 0.05, 0.45, 0.4], ...
               'String', displayText, ...
               'FontSize', 9, 'FontName', 'Microsoft YaHei', ...
               'BackgroundColor', [0.96 0.96 0.96], 'FaceAlpha', 0.85, ...
               'EdgeColor', [0.4 0.4 0.4], 'LineWidth', 1, ...
               'FitBoxToText', 'on');
end