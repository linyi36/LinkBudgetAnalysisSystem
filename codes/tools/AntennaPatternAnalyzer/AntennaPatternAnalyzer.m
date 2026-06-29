function AntennaPatternAnalyzer()
% ANTENNAPATTERNANALYZER2 天线方向图 3D 分析、旋转映射与验证核心工具
%
% Syntax (语法):
%   AntennaPatternAnalyzer()
%
% Description (描述):
%   本程序用于读取标准化 CSV 天线方向图数据，进行坐标网格重构与空间插值。
%   支持运行后强制弹出 UI 菜单，由用户动态指定测试 Tx（发射）或 Rx（接收）天线。
%   程序自动联动外部大系统配置文件，动态匹配并读取姿态角，执行高精度 3D 姿态
%   旋转映射验证。最终导出 2D 伪彩色图、ROI等高线图、一维切面图以及 3D 极坐标
%   方向图，内置控制台“波束靶心自动追踪比对”功能。
%
% Inputs (输入参数 - 内部 Cfg 结构体或外部 Excel 注入):
%   Cfg.PatternFileName  - [String] CSV 天线方向图文件名
%   Cfg.TargetFreqGHz    - [Double] 目标分析仿真工作频率 (GHz)
%   Cfg.TestTarget       - [String] 测试对象 ('Tx' 或 'Rx')，由 UI 菜单交互输入
%   Cfg.UseScenarioExcel - [Logical] 是否启用外部 Excel 剧本联动 (true/false)
%   Cfg.ScenarioFileName - [String] 联动的大系统剧本配置文件名
%   Cfg.YawDeg           - [Double] 手动偏航角/Excel兜底值 (绕 Z 轴，正值向左，度)
%   Cfg.PitchDeg         - [Double] 手动俯仰角/Excel兜底值 (绕 Y 轴，负值下压，度)
%   Cfg.RollDeg          - [Double] 手动横滚角/Excel兜底值 (绕 X 轴，正值右翻，度)
%   Cfg.RegionName       - [String] 感兴趣区域 (ROI) 的业务名称
%   Cfg.PhiRangeDeg      - [1x2 Double] ROI 方位角分析区间限制 [Min, Max] (度)
%   Cfg.ThetaRangeDeg    - [1x2 Double] ROI 天顶角分析区间限制 [Min, Max] (度)
%   Cfg.GainThresholdDb  - [Double] ROI 统计到达标判定的增益门限阈值 (dBi)
%   Cfg.FixedThetaListDeg- [Array]  动态提取固定 Theta 维度的一维切面扫描角度列表
%   Cfg.FixedPhiListDeg  - [Array]  动态提取固定 Phi 维度的一维切面扫描角度列表
%
% Outputs (输出产物 - 统一存放于 output/[天线名]/ 目录下):
%   1. *Fig100*.png        - 2D 伪彩色全空间分布图 (pcolor)
%   2. *Fig200*.png        - 2D 等高线图 (含 ROI 边界与波束靶心追踪)
%   3. *Fig300*.png        - 3D 极坐标方向全空间能量球面图
%   4. *CutData.csv        - 一维切面数据明细表
%   5. *RegionStats.csv    - ROI 区域统计结果表 (点数、极值、平均值、达标率)
%   6. *AnalysisReport.txt - 综合性能链路底层核心指标纯文本报告
%
% Required Environment (运行环境):
%   MATLAB R2021a 或更高版本 (依赖 scatteredInterpolant 及内置 UI 库)
% =========================================================================

    close all;

    %% 0. 路径设置与环境重构
    ToolDir   = fileparts(mfilename('fullpath'));
    if isempty(ToolDir)
        ToolDir = pwd;
    end
    InputDir  = fullfile(ToolDir, 'input');
    OutputDir = fullfile(ToolDir, 'output');

    if ~exist(InputDir, 'dir'), mkdir(InputDir); end
    if ~exist(OutputDir, 'dir'), mkdir(OutputDir); end

    addpath(genpath(ToolDir));

    fprintf('\n========== AntennaPatternAnalyzer ==========\n');
    fprintf('Tool dir   : %s\n', ToolDir);
    fprintf('Input dir  : %s\n', InputDir);
    fprintf('Output dir : %s\n', OutputDir);
    fprintf('============================================\n');

    %% 1. 用户参数配置中心
    Cfg = struct();
    Cfg.PatternFileName = 'test_pattern_patch.csv'; 
    Cfg.TargetFreqGHz   = 4.95;

    % ==========================================================
    % 🌟 【强焦点交互菜单】：运行后强制弹出
    % ==========================================================
    ChoiceIdx = menu('请选择本次 3D 打靶验证的目标天线：', ...
                     'Tx (发射天线 - 机体安装偏角)', ...
                     'Rx (接收天线 - 地面/车载安装偏角)');
                     
    if ChoiceIdx == 2
        Cfg.TestTarget = 'Rx';
    else
        Cfg.TestTarget = 'Tx';
        if ChoiceIdx == 0
            fprintf('?提示: 您未作选择，系统默认切换至发射天线(Tx)模式。\n');
        end
    end
    % ==========================================================

    % --- 核心数据驱动开关：是否联动大系统 Excel 剧本 ---
    Cfg.UseScenarioExcel = true; 
    Cfg.ScenarioFileName = 'Scenario_Config.xlsx';
    
    % 手动/Excel数据空缺时的安全兜底姿态角
    Cfg.YawDeg   = 0;   
    Cfg.PitchDeg = -60; 
    Cfg.RollDeg  = 0;   

    % ROI 区域性能统计配置区
    Cfg.RegionName      = 'TailPm15';
    Cfg.PhiRangeDeg     = [75, 105];
    Cfg.ThetaRangeDeg   = [75, 105];
    Cfg.GainThresholdDb = -5;

    % 切面动态分析提取配置区
    Cfg.FixedThetaListDeg = [75, 90, 105];
    Cfg.FixedPhiListDeg   = [90, 270];

    Cfg.FlagShowFigure = true;
    Cfg.FlagOpenSlider = true;

    %% 2. 智能文件合规性检查
    PatternFilePath = fullfile(InputDir, Cfg.PatternFileName);
    if ~exist(PatternFilePath, 'file')
        fprintf('\n⚠️ 警告: 默认路径下未找到方向图 %s\n', Cfg.PatternFileName);
        [selFile, selPath] = uigetfile('*.csv', ['请手动定位: ', Cfg.PatternFileName]);
        if isequal(selFile, 0)
            error('AntennaAnalyzer:UserCancel', '%s', '用户取消了文件选择，程序终止。');
        end
        PatternFilePath = fullfile(selPath, selFile);
        Cfg.PatternFileName = selFile;
    end

    [~, PatternName, ~] = fileparts(Cfg.PatternFileName);
    PatternOutDir = fullfile(OutputDir, PatternName);
    if ~exist(PatternOutDir, 'dir')
        mkdir(PatternOutDir);
    end

    %% 2.5 剧本联动控制模块
    if Cfg.UseScenarioExcel
        fprintf('\n========== 尝试联动大系统剧本 (Excel) ==========\n');
        ScenarioPaths = {
            fullfile(ToolDir, Cfg.ScenarioFileName), ...
            fullfile(ToolDir, '..', Cfg.ScenarioFileName), ...
            fullfile(ToolDir, '..', '..', Cfg.ScenarioFileName), ...
            fullfile(ToolDir, '..', '..', 'input', Cfg.ScenarioFileName)
        };
        
        FoundExcel = false;
        for idxPath = 1:length(ScenarioPaths)
            if exist(ScenarioPaths{idxPath}, 'file')
                Cfg = ReadAnglesFromExcel(ScenarioPaths{idxPath}, Cfg);
                FoundExcel = true;
                break;
            end
        end
        
        if ~FoundExcel
            fprintf('寻址失败：未搜寻到剧本 [%s]，启动硬编码兜底。\n', Cfg.ScenarioFileName);
        end
        fprintf('================================================\n');
    end

    fprintf('\n========== Input Configuration ==========\n');
    fprintf('Pattern file      : %s\n', PatternFilePath);
    fprintf('Test Target Role  : %s\n', Cfg.TestTarget);
    fprintf('Target frequency  : %.3f GHz\n', Cfg.TargetFreqGHz);
    fprintf('Region name       : %s\n', Cfg.RegionName);
    fprintf('Phi range         : %.2f ~ %.2f deg\n', Cfg.PhiRangeDeg(1), Cfg.PhiRangeDeg(2));
    fprintf('Theta range       : %.2f ~ %.2f deg\n', Cfg.ThetaRangeDeg(1), Cfg.ThetaRangeDeg(2));
    fprintf('Gain threshold    : %.3f dBi\n', Cfg.GainThresholdDb);
    fprintf('=========================================\n');

    %% 3. 数据解析核心
    Pattern = ReadAntennaPatternCsv(PatternFilePath, Cfg.TargetFreqGHz);

    %% 3.1 核心手写旋转矩阵执行与靶心坐标验证
    [maxGainOrig, maxIdxOrig] = max(Pattern.GainGrid(:));
    [rowOrig, colOrig] = ind2sub(size(Pattern.GainGrid), maxIdxOrig);
    PhiOrig   = Pattern.PhiGrid(rowOrig, colOrig);
    ThetaOrig = Pattern.ThetaGrid(rowOrig, colOrig);

    if any([Cfg.YawDeg, Cfg.PitchDeg, Cfg.RollDeg] ~= 0)
        fprintf('\n========== 3D 旋转算法严谨性验证 ==========\n');
        fprintf('测试天线角色 : %s\n', Cfg.TestTarget);
        fprintf('注入机体姿态 : Yaw = %.1f°, Pitch = %.1f°, Roll = %.1f°\n', Cfg.YawDeg, Cfg.PitchDeg, Cfg.RollDeg);
        fprintf('旋转前波束中心: Phi = %.1f°, Theta = %.1f° (增益: %.3f dBi)\n', PhiOrig, ThetaOrig, maxGainOrig);
        
        Pattern = RotateAntennaPattern(Pattern, Cfg.YawDeg, Cfg.PitchDeg, Cfg.RollDeg);
        
        [maxGainNew, maxIdxNew] = max(Pattern.GainGrid(:));
        [rowNew, colNew] = ind2sub(size(Pattern.GainGrid), maxIdxNew);
        PhiNew   = Pattern.PhiGrid(rowNew, colNew);
        ThetaNew = Pattern.ThetaGrid(rowNew, colNew);
        
        fprintf('旋转后波束中心: Phi = %.1f°, Theta = %.1f° (增益: %.3f dBi)\n', PhiNew, ThetaNew, maxGainNew);
        fprintf('============================================\n');
    else
        fprintf('\n[注] 当前未注入任何姿态偏角 (Yaw=0, Pitch=0, Roll=0)。\n');
        fprintf('标准基准波束中心: Phi = %.1f°, Theta = %.1f° (增益: %.3f dBi)\n', PhiOrig, ThetaOrig, maxGainOrig);
    end

    %% 4. 二维/三维图形重构模块
    % 直接调用函数而不进行赋值，即可消除“变量未使用”的警告及等号语法错误
    PlotPatternOverviewFigures(Pattern, Cfg, PatternOutDir, Cfg.FlagShowFigure);

    %% 5. 一维切面数据提取
    CutResult = PlotPatternCuts(Pattern, Cfg.FixedThetaListDeg, Cfg.FixedPhiListDeg, Cfg.GainThresholdDb, PatternOutDir, Cfg.FlagShowFigure);

    %% 6. 指定区域增益统计 (感兴趣区域 ROI)
    RegionStats = AnalyzeGainRegion(Pattern, Cfg.PhiRangeDeg, Cfg.ThetaRangeDeg, Cfg.GainThresholdDb, Cfg.RegionName);
    RegionCsvPath = fullfile(PatternOutDir, [PatternName, '_RegionStats.csv']);
    writetable(struct2table(RegionStats), RegionCsvPath);

    %% 7. 动态构建全空间关键物理方向增益表
    KeyDirTable = BuildKeyDirectionGainTable(Pattern);
    KeyDirCsvPath = fullfile(PatternOutDir, [PatternName, '_KeyDirectionGain.csv']);
    writetable(KeyDirTable, KeyDirCsvPath);

    %% 8. 闭环输出结构化工程分析报告 TXT
    ReportPath = fullfile(PatternOutDir, [PatternName, '_AnalysisReport.txt']);
    WritePatternAnalysisReport(ReportPath, Pattern, RegionStats, KeyDirTable, CutResult);

    %% 9. 智能唤起高级交互式滑块游标查询 GUI
    if Cfg.FlagOpenSlider
        fprintf('\n正在打开 Phi / Theta 滑块交互界面...\n');
        OpenPatternSlider(Pattern, Cfg);
    end

    %% 10. 控制台最终日志总结
    PrintRegionStatsSafe(RegionStats, Cfg);
    fprintf('\n========== AntennaPatternAnalyzer finished ==========\n');
end

%% ========================================================================
%  标准工程子函数区 (Subfunctions Block) - 严格 0 警告显式句柄重构版
% ========================================================================

function Cfg = ReadAnglesFromExcel(FilePath, Cfg)
    try
        opts = detectImportOptions(FilePath);
        opts.VariableNamingRule = 'preserve';
        T = readtable(FilePath, opts);
        
        fprintf('✅ 成功加载大系统剧本: %s\n', FilePath);
        
        VarNames = string(T.Properties.VariableNames);
        idxName  = find(strcmpi(VarNames, 'ParamName'), 1);
        idxValue = find(strcmpi(VarNames, 'ParamValue'), 1);
        
        if ~isempty(idxName) && ~isempty(idxValue)
            Names = string(T{:, idxName});
            TargetPrefix = lower(Cfg.TestTarget); 
            
            rowY = find(contains(lower(Names), [TargetPrefix, '_mountyaw']), 1);
            if ~isempty(rowY)
                val = str2double(string(T{rowY, idxValue}));
                if ~isnan(val)
                    Cfg.YawDeg = val; 
                    fprintf('   -> 同步 Excel 剧本 [%s] Yaw    = %.2f°\n', Cfg.TestTarget, val); 
                end
            end
            
            rowP = find(contains(lower(Names), [TargetPrefix, '_mountpitch']), 1);
            if ~isempty(rowP)
                val = str2double(string(T{rowP, idxValue}));
                if ~isnan(val)
                    Cfg.PitchDeg = val; 
                    fprintf('   -> 同步 Excel 剧本 [%s] Pitch = %.2f°\n', Cfg.TestTarget, val); 
                end
            end
            
            rowR = find(contains(lower(Names), [TargetPrefix, '_mountroll']), 1);
            if ~isempty(rowR)
                val = str2double(string(T{rowR, idxValue}));
                if ~isnan(val)
                    Cfg.RollDeg = val; 
                    fprintf('   -> 同步 Excel 剧本 [%s] Roll  = %.2f°\n', Cfg.TestTarget, val); 
                end
            end
            fprintf('?提示: 解析成功。已精准锁定 %s 天线的姿态角。\n', Cfg.TestTarget);
        else
            fprintf('解析失败：Excel 结构不符合标准的 ParamName/ParamValue 字典要求。\n');
        end
    catch ME
        fprintf('联动异常 (%s)，程序已自动开启安全兜底保护。\n', ME.message);
    end
end

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
    fprintf('Gain min/mean/max = %.3f / %.3f / %.3f dBi\n', ...
        RegionStats.GainMinDb, RegionStats.GainMeanDb, RegionStats.GainMaxDb);
    
    if isfield(RegionStats, 'PercentGreaterThanThreshold')
        PercentAbove = RegionStats.PercentGreaterThanThreshold;
    else
        PercentAbove = NaN;
    end
    
    if isnan(PercentAbove)
        fprintf('Gain > threshold percent = 字段检索失败。\n');
    else
        fprintf('Gain > threshold percent = %.2f %%\n', PercentAbove);
    end
    fprintf('============================================\n');
end

function RotatedPattern = RotateAntennaPattern(Pattern, YawDeg, PitchDeg, RollDeg)
    Alpha = deg2rad(YawDeg); 
    Beta = deg2rad(PitchDeg); 
    Gamma = deg2rad(RollDeg);
    
    Rz = [cos(Alpha) -sin(Alpha) 0; sin(Alpha) cos(Alpha) 0; 0 0 1];
    Ry = [cos(Beta) 0 sin(Beta); 0 1 0; -sin(Beta) 0 cos(Beta)];
    Rx = [1 0 0; 0 cos(Gamma) -sin(Gamma); 0 sin(Gamma) cos(Gamma)];
    R = Rz * Ry * Rx; 
    
    PhiRad = deg2rad(Pattern.PhiGrid); 
    ThetaRad = deg2rad(Pattern.ThetaGrid);
    
    X = sin(ThetaRad) .* cos(PhiRad); 
    Y = sin(ThetaRad) .* sin(PhiRad); 
    Z = cos(ThetaRad);
    
    OriginalShape = size(X); 
    XYZ = [X(:)'; Y(:)'; Z(:)']; 
    XYZ_Rotated = R * XYZ;
    
    X_new = reshape(XYZ_Rotated(1,:), OriginalShape); 
    Y_new = reshape(XYZ_Rotated(2,:), OriginalShape); 
    Z_new = reshape(XYZ_Rotated(3,:), OriginalShape);
    
    R_new = sqrt(X_new.^2 + Y_new.^2 + Z_new.^2); 
    ThetaRad_new = acos(Z_new ./ R_new); 
    PhiRad_new = atan2(Y_new, X_new);
    
    PhiDeg_new = mod(rad2deg(PhiRad_new), 360); 
    ThetaDeg_new = rad2deg(ThetaRad_new);
    
    % 精准屏蔽插值产生的无害散点重叠警告 (MATLAB 2021标准做法)
    warning('off', 'MATLAB:scatteredInterpolant:DupPtsAvWarnId');
    F = scatteredInterpolant(PhiDeg_new(:), ThetaDeg_new(:), Pattern.GainGrid(:), 'linear', 'nearest');
    RotatedPattern = Pattern; 
    RotatedPattern.GainGrid = F(Pattern.PhiGrid, Pattern.ThetaGrid);
    warning('on', 'MATLAB:scatteredInterpolant:DupPtsAvWarnId'); 
end

function Pattern = ReadAntennaPatternCsv(FilePath, TargetFreqGHz)
    if ~exist(FilePath, 'file')
        error('AntennaAnalyzer:FileNotFound', '%s', '输入方向图路径不合法'); 
    end
    try 
        DataTable = readtable(FilePath, 'VariableNamingRule', 'preserve'); 
    catch
        DataTable = readtable(FilePath); 
    end
    VarNames = string(DataTable.Properties.VariableNames);
    NormNames = lower(regexprep(VarNames, '[\s_\[\]\(\)]', ''));

    IdxPhi = FindColumnIndex(NormNames, {'phi'}); 
    IdxTheta = FindColumnIndex(NormNames, {'theta'}); 
    IdxGain = FindColumnIndex(NormNames, {'realizedgain', 'gain'}); 
    IdxFreq = FindColumnIndex(NormNames, {'freq'});
    
    if isempty(IdxPhi) || isempty(IdxTheta) || isempty(IdxGain)
        error('AntennaAnalyzer:InvalidHeader', '%s', 'CSV 表头解析失败。'); 
    end

    if nargin < 2 || isempty(TargetFreqGHz), TargetFreqGHz = NaN; end
    SelectedFreqGHz = NaN;
    if ~isempty(IdxFreq)
        FreqAll = DataTable{:, IdxFreq}; 
        FreqVec = unique(FreqAll(:));
        if isnan(TargetFreqGHz)
            SelectedFreqGHz = FreqVec(1); 
        else
            [~, IdxNearest] = min(abs(FreqVec - TargetFreqGHz)); 
            SelectedFreqGHz = FreqVec(IdxNearest); 
        end
        DataTable = DataTable(abs(FreqAll - SelectedFreqGHz) < 1e-9, :);
    end

    Phi = DataTable{:, IdxPhi}(:); 
    Theta = DataTable{:, IdxTheta}(:); 
    Gain = DataTable{:, IdxGain}(:);
    
    PhiUnique = unique(Phi); 
    ThetaUnique = unique(Theta);
    [PhiGrid, ThetaGrid] = meshgrid(PhiUnique, ThetaUnique); 
    GainGrid = nan(size(PhiGrid));

    for IdxPoint = 1:numel(Gain)
        [~, IdxPhiGrid] = min(abs(PhiUnique - Phi(IdxPoint))); 
        [~, IdxThetaGrid] = min(abs(ThetaUnique - Theta(IdxPoint)));
        GainGrid(IdxThetaGrid, IdxPhiGrid) = Gain(IdxPoint);
    end

    if any(isnan(GainGrid(:)))
        warning('off', 'MATLAB:scatteredInterpolant:DupPtsAvWarnId');
        F_interp = scatteredInterpolant(Phi, Theta, Gain, 'linear', 'none');
        GainGridInterp = F_interp(PhiGrid, ThetaGrid);
        FillMask = isnan(GainGrid) & ~isnan(GainGridInterp); 
        GainGrid(FillMask) = GainGridInterp(FillMask);
        warning('on', 'MATLAB:scatteredInterpolant:DupPtsAvWarnId');
    end
    if any(isnan(GainGrid(:)))
        GainNoNan = Gain(~isnan(Gain)); 
        GainGrid(isnan(GainGrid)) = min(GainNoNan); 
    end

    Pattern = struct('FilePath', char(FilePath), 'TargetFreqGHz', TargetFreqGHz, 'SelectedFreqGHz', SelectedFreqGHz, ...
        'Phi', Phi, 'Theta', Theta, 'Gain', Gain, 'PhiUnique', PhiUnique, 'ThetaUnique', ThetaUnique, ...
        'PhiGrid', PhiGrid, 'ThetaGrid', ThetaGrid, 'GainGrid', GainGrid);
    [~, FileBaseName, FileExt] = fileparts(FilePath); 
    Pattern.FileName = [FileBaseName, FileExt]; 
    Pattern.FileBaseName = FileBaseName;
    Pattern.PhiRangeDeg = [min(Phi), max(Phi)]; 
    Pattern.ThetaRangeDeg = [min(Theta), max(Theta)]; 
    Pattern.GainRangeDb = [min(Gain), max(Gain)];
end

function Idx = FindColumnIndex(NormNames, Keywords)
    Idx = [];
    for IdxKey = 1:numel(Keywords)
        Hit = find(contains(NormNames, lower(Keywords{IdxKey})), 1);
        if ~isempty(Hit)
            Idx = Hit; 
            return; 
        end
    end
end

function RegionStats = AnalyzeGainRegion(Pattern, PhiRangeDeg, ThetaRangeDeg, ThresholdDb, RegionName)
    if nargin < 5 || isempty(RegionName), RegionName = 'Region'; end
    if nargin < 4 || isempty(ThresholdDb), ThresholdDb = -Inf; end

    PhiMin = min(PhiRangeDeg); PhiMax = max(PhiRangeDeg); 
    ThetaMin = min(ThetaRangeDeg); ThetaMax = max(ThetaRangeDeg);
    
    if PhiMin <= PhiMax
        PhiMask = Pattern.PhiGrid >= PhiMin & Pattern.PhiGrid <= PhiMax; 
    else
        PhiMask = Pattern.PhiGrid >= PhiMin | Pattern.PhiGrid <= PhiMax; 
    end
    ThetaMask = Pattern.ThetaGrid >= ThetaMin & Pattern.ThetaGrid <= ThetaMax; 
    RegionMask = PhiMask & ThetaMask;
    GainValid = Pattern.GainGrid(RegionMask); 
    GainValid = GainValid(~isnan(GainValid));

    if isempty(GainValid)
        error('AntennaAnalyzer:EmptyRegion', '%s', '感兴趣区域 ROI 内无任何有效矢量格点。'); 
    end

    RegionStats = struct('RegionName', string(RegionName), 'PhiMinDeg', PhiMin, 'PhiMaxDeg', PhiMax, 'ThetaMinDeg', ThetaMin, 'ThetaMaxDeg', ThetaMax, ...
        'ThresholdDb', ThresholdDb, 'NumValidPoints', numel(GainValid), 'GainMinDb', min(GainValid), 'GainMeanDb', mean(GainValid), ...
        'GainMaxDb', max(GainValid), 'GainMedianDb', median(GainValid), 'GainStdDb', std(GainValid), ...
        'PercentGreaterThanThreshold', 100 * mean(GainValid > ThresholdDb));
    RegionStats.PercentLessOrEqualThreshold = 100 * mean(GainValid <= ThresholdDb); 
    RegionStats.PassFlag = RegionStats.PercentGreaterThanThreshold >= 100;
end

function KeyDirTable = BuildKeyDirectionGainTable(Pattern)
    ThetaMin = min(Pattern.ThetaUnique); ThetaMax = max(Pattern.ThetaUnique);
    if ThetaMin <= 0 && ThetaMax >= 180
        DirectionName = {'head'; 'tail'; 'side0'; 'side180'; 'top'}; 
        PhiDeg = [270; 90; 0; 180; 0]; 
        ThetaDeg = [90; 90; 90; 90; 0];
    else
        DirectionName = {'top'; 'horizonPositive'; 'horizonNegative'; 'phi0Theta0'}; 
        PhiDeg = [0; 0; 0; 0]; 
        ThetaDeg = [0; 90; -90; 0];
    end
    GainDb = zeros(numel(PhiDeg), 1); 
    for Idx = 1:numel(PhiDeg)
        GainDb(Idx, 1) = QueryPatternGain(Pattern, PhiDeg(Idx), ThetaDeg(Idx)); 
    end
    KeyDirTable = table(DirectionName, PhiDeg, ThetaDeg, GainDb, 'VariableNames', {'DirectionName', 'PhiDeg', 'ThetaDeg', 'GainDb'});
end

function GainDb = QueryPatternGain(Pattern, PhiDeg, ThetaDeg)
    PhiDeg = mod(PhiDeg, 360); 
    GainDb = interp2(Pattern.PhiGrid, Pattern.ThetaGrid, Pattern.GainGrid, PhiDeg, ThetaDeg, 'linear', NaN);
    NanMask = isnan(GainDb);
    if any(NanMask(:))
        GainNearest = interp2(Pattern.PhiGrid, Pattern.ThetaGrid, Pattern.GainGrid, PhiDeg, ThetaDeg, 'nearest', NaN); 
        GainDb(NanMask) = GainNearest(NanMask); 
    end
end

function AngleOut = WrapTo180Local(AngleIn)
    AngleOut = mod(AngleIn + 180, 360) - 180;
end

function CutResult = PlotPatternCuts(Pattern, FixedThetaListDeg, FixedPhiListDeg, ThresholdDb, OutputDir, FlagShowFigure)
    if nargin < 6, FlagShowFigure = true; end
    if nargin < 5 || isempty(OutputDir), OutputDir = pwd; end
    if ~exist(OutputDir, 'dir'), mkdir(OutputDir); end
    if nargin < 4, ThresholdDb = NaN; end

    CutResult = struct('ThetaCutPng', '', 'PhiCutPng', '', 'CutCsv', fullfile(OutputDir, [Pattern.FileBaseName, '_CutData.csv']));
    TotalCuts = numel(FixedThetaListDeg) + numel(FixedPhiListDeg);
    CellCutType = cell(TotalCuts, 1); CellFixedAngle = cell(TotalCuts, 1); 
    CellSweepAngle = cell(TotalCuts, 1); CellGain = cell(TotalCuts, 1); IdxCell = 0; 
    FigVisible = 'on'; if ~FlagShowFigure, FigVisible = 'off'; end

    if ~isempty(FixedThetaListDeg)
        FigTheta = figure('Color', 'w', 'Visible', FigVisible); 
        AxTheta = axes('Parent', FigTheta);
        hold(AxTheta, 'on');
        for Idx = 1:numel(FixedThetaListDeg)
            TargetTheta = FixedThetaListDeg(Idx); 
            [~, IdxTheta] = min(abs(Pattern.ThetaUnique - TargetTheta)); 
            ActualTheta = Pattern.ThetaUnique(IdxTheta);
            PhiSweep = Pattern.PhiUnique(:); 
            GainCut = Pattern.GainGrid(IdxTheta, :).';
            plot(AxTheta, PhiSweep, GainCut, 'LineWidth', 1.5, 'DisplayName', sprintf('Theta=%.2f°', ActualTheta));
            
            IdxCell = IdxCell + 1; 
            CellCutType{IdxCell} = repmat({'FixedTheta'}, numel(PhiSweep), 1); 
            CellFixedAngle{IdxCell} = repmat(ActualTheta, numel(PhiSweep), 1); 
            CellSweepAngle{IdxCell} = PhiSweep; 
            CellGain{IdxCell} = GainCut;
        end
        AddThresholdLine(AxTheta, ThresholdDb, Pattern.PhiUnique); 
        xlabel(AxTheta, 'Phi [deg]'); ylabel(AxTheta, 'Gain [dBi]'); 
        title(AxTheta, sprintf('%s: fixed Theta, scan Phi', Pattern.FileBaseName), 'Interpreter', 'none'); 
        legend(AxTheta, 'Location', 'best'); grid(AxTheta, 'on'); hold(AxTheta, 'off');
        CutResult.ThetaCutPng = fullfile(OutputDir, [Pattern.FileBaseName, '_FixedThetaScanPhi.png']); 
        SaveFigureLocal(FigTheta, CutResult.ThetaCutPng);
    end

    if ~isempty(FixedPhiListDeg)
        FigPhi = figure('Color', 'w', 'Visible', FigVisible); 
        AxPhi = axes('Parent', FigPhi);
        hold(AxPhi, 'on');
        for Idx = 1:numel(FixedPhiListDeg)
            TargetPhi = mod(FixedPhiListDeg(Idx), 360); 
            % 【关键修复】移除了原代码末尾多余的一个反括号 ')'
            [~, IdxPhi] = min(abs(WrapTo180Local(Pattern.PhiUnique - TargetPhi))); 
            ActualPhi = Pattern.PhiUnique(IdxPhi);
            ThetaSweep = Pattern.ThetaUnique(:); 
            GainCut = Pattern.GainGrid(:, IdxPhi);
            plot(AxPhi, ThetaSweep, GainCut, 'LineWidth', 1.5, 'DisplayName', sprintf('Phi=%.2f°', ActualPhi));
            
            IdxCell = IdxCell + 1; 
            CellCutType{IdxCell} = repmat({'FixedPhi'}, numel(ThetaSweep), 1); 
            CellFixedAngle{IdxCell} = repmat(ActualPhi, numel(ThetaSweep), 1); 
            CellSweepAngle{IdxCell} = ThetaSweep; 
            CellGain{IdxCell} = GainCut;
        end
        AddThresholdLine(AxPhi, ThresholdDb, Pattern.ThetaUnique); 
        xlabel(AxPhi, 'Theta [deg]'); ylabel(AxPhi, 'Gain [dBi]'); 
        title(AxPhi, sprintf('%s: fixed Phi, scan Theta', Pattern.FileBaseName), 'Interpreter', 'none'); 
        legend(AxPhi, 'Location', 'best'); grid(AxPhi, 'on'); hold(AxPhi, 'off');
        CutResult.PhiCutPng = fullfile(OutputDir, [Pattern.FileBaseName, '_FixedPhiScanTheta.png']); 
        SaveFigureLocal(FigPhi, CutResult.PhiCutPng);
    end

    if IdxCell > 0
        CutTable = table(vertcat(CellCutType{1:IdxCell}), vertcat(CellFixedAngle{1:IdxCell}), vertcat(CellSweepAngle{1:IdxCell}), vertcat(CellGain{1:IdxCell}), 'VariableNames', {'CutType', 'FixedAngleDeg', 'SweepAngleDeg', 'GainDb'});
        writetable(CutTable, CutResult.CutCsv);
    end
end

function AddThresholdLine(Ax, ThresholdDb, XVec)
    if ~isnan(ThresholdDb)
        XMin = min(XVec); XMax = max(XVec); 
        plot(Ax, [XMin, XMax], [ThresholdDb, ThresholdDb], 'k--', 'LineWidth', 1.2, 'DisplayName', sprintf('Threshold %.2f dBi', ThresholdDb));
    end
end

function OverviewResult = PlotPatternOverviewFigures(Pattern, Cfg, OutputDir, FlagShowFigure)
    if nargin < 4 || isempty(FlagShowFigure), FlagShowFigure = true; end
    if ~exist(OutputDir, 'dir'), mkdir(OutputDir); end

    PhiGrid = Pattern.PhiGrid; 
    ThetaGrid = Pattern.ThetaGrid; 
    GainGrid = Pattern.GainGrid; 
    PhiUnique = Pattern.PhiUnique; 
    ThetaUnique = Pattern.ThetaUnique; 
    PatternName = Pattern.FileBaseName;
    
    OverviewResult = struct('HeatmapPng', fullfile(OutputDir, [PatternName, '_Fig100_天线方向增益二维分布图.png']), ...
        'ContourRoiPng', fullfile(OutputDir, [PatternName, '_Fig200_天线方向增益等高线图.png']), ...
        'Spherical3dPng', fullfile(OutputDir, [PatternName, '_Fig300_天线三维极坐标方向图.png']), ...
        'PatternCustomPng', fullfile(OutputDir, [PatternName, '_Fig400_patternCustom三维方向图.png']));
    VisibleState = 'off'; if FlagShowFigure, VisibleState = 'on'; end

    %% Fig.100 二维彩色矩阵
    Fig100 = figure(100); set(Fig100, 'Visible', VisibleState, 'Color', 'w'); clf(Fig100);
    Ax100 = axes('Parent', Fig100);
    pcolor(Ax100, PhiGrid, ThetaGrid, GainGrid); shading(Ax100, 'interp'); 
    colorbar(Ax100); colormap(Ax100, 'jet'); grid(Ax100, 'on'); 
    xlabel(Ax100, '\phi 方位角 (deg)'); ylabel(Ax100, '\theta 俯仰角 (deg)'); title(Ax100, '天线方向增益二维分布图 (dBi)');
    SaveFigureLocal(Fig100, OverviewResult.HeatmapPng);

    %% Fig.200 ROI等高线图与靶心捕捉
    Fig200 = figure(200); set(Fig200, 'Visible', VisibleState, 'Color', 'w'); clf(Fig200);
    Ax200 = axes('Parent', Fig200);
    contourf(Ax200, PhiGrid, ThetaGrid, GainGrid, 20, 'LineColor', 'none'); 
    hold(Ax200, 'on'); 
    contour(Ax200, PhiGrid, ThetaGrid, GainGrid, 20, 'LineColor', [0.12 0.12 0.12], 'LineStyle', '-', 'LineWidth', 0.35);
    colorbar(Ax200); colormap(Ax200, 'jet'); grid(Ax200, 'on'); 
    xlabel(Ax200, '\phi 方位角 (deg)'); ylabel(Ax200, '\theta 俯仰角 (deg)'); title(Ax200, '天线方向增益等高线图 (dBi)');
    OverviewResult.RoiStats = AnalyzeRoiForPlotLocal(PhiGrid, ThetaGrid, GainGrid, Cfg.PhiRangeDeg(1), Cfg.PhiRangeDeg(2), Cfg.ThetaRangeDeg(1), Cfg.ThetaRangeDeg(2), Cfg.GainThresholdDb);
    DrawRoiOnAxesLocal(Ax200, OverviewResult.RoiStats); 
    hold(Ax200, 'off');
    SaveFigureLocal(Fig200, OverviewResult.ContourRoiPng);

    %% Fig.300 线性立体空间球面增益辐射气球
    Fig300 = figure(300); set(Fig300, 'Visible', VisibleState, 'Color', 'w'); clf(Fig300);
    Ax300 = axes('Parent', Fig300);
    GainLinear = 10 .^ (GainGrid ./ 20); 
    PhiRad = deg2rad(PhiGrid); ThetaRad = deg2rad(ThetaGrid);
    XCoord = GainLinear .* sin(ThetaRad) .* cos(PhiRad); 
    YCoord = GainLinear .* sin(ThetaRad) .* sin(PhiRad); 
    ZCoord = GainLinear .* cos(ThetaRad);
    
    surf(Ax300, XCoord, YCoord, ZCoord, GainGrid); shading(Ax300, 'interp'); 
    ColorBarHandle = colorbar(Ax300); ColorBarHandle.Label.String = '增益 (dBi)'; colormap(Ax300, 'jet');
    axis(Ax300, 'equal'); grid(Ax300, 'on'); 
    xlabel(Ax300, 'X  [\phi=0°, \theta=90°]'); ylabel(Ax300, 'Y  [\phi=90°, \theta=90°]'); zlabel(Ax300, 'Z  [\theta=0°]'); 
    title(Ax300, '天线三维极坐标方向图 (形状: 真实线性幅度, 颜色: 真实 dBi)');
    view(Ax300, 45, 30); rotate3d(Fig300, 'on'); 
    SaveFigureLocal(Fig300, OverviewResult.Spherical3dPng);

    %% Fig.400 工具箱特定函数渲染兜底
    Fig400 = figure(400); set(Fig400, 'Visible', VisibleState, 'Color', 'w'); clf(Fig400);
    try
        if exist('patternCustom', 'file') == 2
            patternCustom(GainGrid.', ThetaUnique.', PhiUnique.'); 
            title('天线三维方向图 - patternCustom (dBi)'); rotate3d(Fig400, 'on');
            SaveFigureLocal(Fig400, OverviewResult.PatternCustomPng); 
            OverviewResult.PatternCustomGenerated = true;
        else
            OverviewResult.PatternCustomGenerated = false; if ishandle(Fig400), close(Fig400); end
        end
    catch
        OverviewResult.PatternCustomGenerated = false; if ishandle(Fig400), close(Fig400); end
    end
end

function RoiStats = AnalyzeRoiForPlotLocal(PhiGrid, ThetaGrid, GainGrid, PhiMin, PhiMax, ThetaMin, ThetaMax, ThresholdDb)
    RoiMask = PhiGrid >= PhiMin & PhiGrid <= PhiMax & ThetaGrid >= ThetaMin & ThetaGrid <= ThetaMax & ~isnan(GainGrid);
    GainValid = GainGrid(RoiMask);
    if isempty(GainValid)
        RoiStats = struct('PhiMin', PhiMin, 'PhiMax', PhiMax, 'ThetaMin', ThetaMin, 'ThetaMax', ThetaMax, ...
            'GainMin', NaN, 'GainMean', NaN, 'GainMax', NaN, 'GainMedian', NaN, 'GainStd', NaN, ...
            'PercentAbove', 0, 'PassFlag', 0, 'NumValidPoints', 0, 'PhiAtMax', NaN, 'ThetaAtMax', NaN, 'PhiAtMin', NaN, 'ThetaAtMin', NaN); 
        return;
    end
    MaskedGain = GainGrid; 
    MaskedGain(~RoiMask) = NaN; 
    
    [GainMax, IdxMax] = max(MaskedGain(:)); 
    [GainMin, IdxMin] = min(MaskedGain(:));
    
    [RowMax, ColMax] = ind2sub(size(GainGrid), IdxMax); 
    [RowMin, ColMin] = ind2sub(size(GainGrid), IdxMin);
    
    RoiStats = struct('PhiMin', PhiMin, 'PhiMax', PhiMax, 'ThetaMin', ThetaMin, 'ThetaMax', ThetaMax, ...
        'ThresholdDb', ThresholdDb, 'GainMax', GainMax, 'GainMin', GainMin, 'GainMean', mean(GainValid), ...
        'GainMedian', median(GainValid), 'GainStd', std(GainValid), 'GainRange', GainMax - GainMin, ...
        'PercentGreaterThanThreshold', 100 * mean(GainValid > ThresholdDb), 'NumValidPoints', numel(GainValid), ...
        'PhiAtMax', PhiGrid(RowMax, ColMax), 'ThetaAtMax', ThetaGrid(RowMax, ColMax), ...
        'PhiAtMin', PhiGrid(RowMin, ColMin), 'ThetaAtMin', ThetaGrid(RowMin, ColMin));
end

function DrawRoiOnAxesLocal(AxesHandle, RoiStats)
    if ~isfield(RoiStats, 'NumValidPoints') || RoiStats.NumValidPoints == 0, return; end
    hold(AxesHandle, 'on');
    RoiX = [RoiStats.PhiMin, RoiStats.PhiMax, RoiStats.PhiMax, RoiStats.PhiMin, RoiStats.PhiMin]; 
    RoiY = [RoiStats.ThetaMin, RoiStats.ThetaMin, RoiStats.ThetaMax, RoiStats.ThetaMax, RoiStats.ThetaMin];
    plot(AxesHandle, RoiX, RoiY, 'w--', 'LineWidth', 2.0, 'DisplayName', 'ROI 边界');
    
    plot(AxesHandle, RoiStats.PhiAtMax, RoiStats.ThetaAtMax, '^w', 'MarkerSize', 10, 'MarkerFaceColor', 'w', 'LineWidth', 1.5, 'DisplayName', sprintf('Max %.2f dBi', RoiStats.GainMax));
    text(AxesHandle, RoiStats.PhiAtMax, RoiStats.ThetaAtMax, sprintf('  Max %.2f dBi', RoiStats.GainMax), 'Color', 'w', 'FontSize', 8, 'FontWeight', 'bold', 'VerticalAlignment', 'bottom');
    
    plot(AxesHandle, RoiStats.PhiAtMin, RoiStats.ThetaAtMin, 'vy', 'MarkerSize', 10, 'MarkerFaceColor', 'y', 'LineWidth', 1.5, 'DisplayName', sprintf('Min %.2f dBi', RoiStats.GainMin));
    text(AxesHandle, RoiStats.PhiAtMin, RoiStats.ThetaAtMin, sprintf('  Min %.2f dBi', RoiStats.GainMin), 'Color', 'y', 'FontSize', 8, 'FontWeight', 'bold', 'VerticalAlignment', 'top');
    legend(AxesHandle, 'Location', 'best', 'TextColor', 'w', 'Color', [0.2 0.2 0.2]); 
    hold(AxesHandle, 'off');
end

function SaveFigureLocal(FigureHandle, OutputPath)
    ParentDir = fileparts(OutputPath); 
    if ~exist(ParentDir, 'dir'), mkdir(ParentDir); end
    warning('off', 'MATLAB:print:FigureTooLargeForPage');
    try 
        exportgraphics(FigureHandle, OutputPath, 'Resolution', 200); 
    catch
        saveas(FigureHandle, OutputPath); 
    end
    warning('on', 'MATLAB:print:FigureTooLargeForPage');
end

function WritePatternAnalysisReport(ReportPath, Pattern, RegionStats, KeyDirTable, CutResult)
    ParentDir = fileparts(ReportPath); 
    if ~exist(ParentDir, 'dir'), mkdir(ParentDir); end
    FileId = fopen(ReportPath, 'w'); 
    if FileId < 0
        error('AntennaAnalyzer:WriteFailed', '%s', '无法写入报告。'); 
    end
    
    fprintf(FileId, 'Antenna Pattern Analyzer Report\n================================\n\n');
    fprintf(FileId, 'Input file      : %s\nSelected freq   : %.6g GHz\nPhi range       : %.3f ~ %.3f deg\nTheta range     : %.3f ~ %.3f deg\nGain range      : %.3f ~ %.3f dBi\n\n', Pattern.FilePath, Pattern.SelectedFreqGHz, Pattern.PhiRangeDeg(1), Pattern.PhiRangeDeg(2), Pattern.ThetaRangeDeg(1), Pattern.ThetaRangeDeg(2), Pattern.GainRangeDb(1), Pattern.GainRangeDb(2));
    fprintf(FileId, 'Region Statistics\n-----------------\nRegion name     : %s\nPhi range       : %.3f ~ %.3f deg\nTheta range     : %.3f ~ %.3f deg\nThreshold       : %.3f dBi\nGain min        : %.3f dBi\nGain mean       : %.3f dBi\nGain max        : %.3f dBi\nGain median     : %.3f dBi\nGain std        : %.3f dB\nGain > threshold: %.2f %%\nPass flag       : %d\n\n', RegionStats.RegionName, RegionStats.PhiMinDeg, RegionStats.PhiMaxDeg, RegionStats.ThetaMinDeg, RegionStats.ThetaMaxDeg, RegionStats.ThresholdDb, RegionStats.GainMinDb, RegionStats.GainMeanDb, RegionStats.GainMaxDb, RegionStats.GainMedianDb, RegionStats.GainStdDb, RegionStats.PercentGreaterThanThreshold, RegionStats.PassFlag);
    fprintf(FileId, 'Key Direction Gain\n------------------\n');
    for Idx = 1:height(KeyDirTable), fprintf(FileId, '%-18s Phi=%8.3f deg, Theta=%8.3f deg, Gain=%8.3f dBi\n', KeyDirTable.DirectionName{Idx}, KeyDirTable.PhiDeg(Idx), KeyDirTable.ThetaDeg(Idx), KeyDirTable.GainDb(Idx)); end
    fprintf(FileId, '\nOutput Files\n------------\nFixed theta cut PNG : %s\nFixed phi cut PNG   : %s\nCut data CSV        : %s\n', CutResult.ThetaCutPng, CutResult.PhiCutPng, CutResult.CutCsv);
    fclose(FileId);
end

function OpenPatternSlider(Pattern, Cfg)
    if nargin < 1 || isempty(Pattern)
        error('AntennaAnalyzer:MissingInput', '%s', 'OpenPatternSlider 需要 Pattern'); 
    end
    if nargin < 2 || isempty(Cfg), Cfg = struct(); end

    PhiGrid = Pattern.PhiGrid; 
    ThetaGrid = Pattern.ThetaGrid; 
    GainGrid = Pattern.GainGrid;
    
    PhiMin = min(PhiGrid(:)); 
    PhiMax = max(PhiGrid(:)); 
    ThetaMin = min(ThetaGrid(:)); 
    ThetaMax = max(ThetaGrid(:));
    
    PhiInit = 0.5 * (PhiMin + PhiMax); 
    ThetaInit = 0.5 * (ThetaMin + ThetaMax);
    if PhiMin <= 90 && PhiMax >= 90 && ThetaMin <= 90 && ThetaMax >= 90
        PhiInit = 90; 
        ThetaInit = 90; 
    end

    GainInit = QueryGainLocal(PhiGrid, ThetaGrid, GainGrid, PhiInit, ThetaInit);
    RoiPhiRange = GetCfgFieldLocal(Cfg, 'PhiRangeDeg', [max(PhiMin, PhiInit - 15), min(PhiMax, PhiInit + 15)]);
    RoiThetaRange = GetCfgFieldLocal(Cfg, 'ThetaRangeDeg', [max(ThetaMin, ThetaInit - 15), min(ThetaMax, ThetaInit + 15)]);
    RoiThreshold = GetCfgFieldLocal(Cfg, 'GainThresholdDb', -5);

    Fig = figure('Name', 'Antenna Pattern Phi/Theta Query and ROI Analysis', 'NumberTitle', 'off', 'Color', 'w', 'Position', [80, 80, 1280, 760]);
    Ax = axes('Parent', Fig, 'Units', 'normalized', 'Position', [0.06, 0.23, 0.62, 0.70]);

    Panel = uipanel('Parent', Fig, 'Title', '方向查询', 'FontWeight', 'bold', 'Units', 'normalized', 'Position', [0.71, 0.55, 0.26, 0.38]);
    ViewModeCheckbox = uicontrol(Panel, 'Style', 'checkbox', 'String', '伪彩色图模式 pcolor', 'Units', 'normalized', 'Value', 0, 'HorizontalAlignment', 'left', 'Position', [0.08, 0.89, 0.84, 0.08]);
    uicontrol(Panel, 'Style', 'text', 'String', 'Phi [deg]', 'Units', 'normalized', 'HorizontalAlignment', 'left', 'Position', [0.08, 0.78, 0.35, 0.06]);
    PhiSlider = uicontrol(Panel, 'Style', 'slider', 'Units', 'normalized', 'Min', PhiMin, 'Max', PhiMax, 'Value', PhiInit, 'Position', [0.08, 0.72, 0.84, 0.05]);
    PhiEdit = uicontrol(Panel, 'Style', 'edit', 'Units', 'normalized', 'String', sprintf('%.2f', PhiInit), 'Position', [0.08, 0.65, 0.84, 0.06]);
    uicontrol(Panel, 'Style', 'text', 'String', 'Theta [deg]', 'Units', 'normalized', 'HorizontalAlignment', 'left', 'Position', [0.08, 0.55, 0.45, 0.06]);
    ThetaSlider = uicontrol(Panel, 'Style', 'slider', 'Units', 'normalized', 'Min', ThetaMin, 'Max', ThetaMax, 'Value', ThetaInit, 'Position', [0.08, 0.49, 0.84, 0.05]);
    ThetaEdit = uicontrol(Panel, 'Style', 'edit', 'Units', 'normalized', 'String', sprintf('%.2f', ThetaInit), 'Position', [0.08, 0.42, 0.84, 0.06]);
    QueryButton = uicontrol(Panel, 'Style', 'pushbutton', 'String', '手动输入后查询', 'Units', 'normalized', 'FontWeight', 'bold', 'Position', [0.08, 0.30, 0.84, 0.08]);
    GainText = uicontrol(Panel, 'Style', 'text', 'Units', 'normalized', 'HorizontalAlignment', 'left', 'FontSize', 11, 'FontWeight', 'bold', 'String', sprintf('当前 Gain = %.3f dBi', GainInit), 'Position', [0.08, 0.16, 0.84, 0.08]);

    RoiPanel = uipanel('Parent', Fig, 'Title', '区域分析 ROI', 'FontWeight', 'bold', 'Units', 'normalized', 'Position', [0.71, 0.08, 0.26, 0.42]);
    uicontrol(RoiPanel, 'Style', 'text', 'String', 'Phi min / max', 'Units', 'normalized', 'HorizontalAlignment', 'left', 'Position', [0.08, 0.86, 0.42, 0.06]);
    RoiPhiMinEdit = uicontrol(RoiPanel, 'Style', 'edit', 'Units', 'normalized', 'String', sprintf('%.2f', RoiPhiRange(1)), 'Position', [0.50, 0.86, 0.18, 0.06]);
    RoiPhiMaxEdit = uicontrol(RoiPanel, 'Style', 'edit', 'Units', 'normalized', 'String', sprintf('%.2f', RoiPhiRange(2)), 'Position', [0.72, 0.86, 0.18, 0.06]);
    uicontrol(RoiPanel, 'Style', 'text', 'String', 'Theta min / max', 'Units', 'normalized', 'HorizontalAlignment', 'left', 'Position', [0.08, 0.77, 0.42, 0.06]);
    RoiThetaMinEdit = uicontrol(RoiPanel, 'Style', 'edit', 'Units', 'normalized', 'String', sprintf('%.2f', RoiThetaRange(1)), 'Position', [0.50, 0.77, 0.18, 0.06]);
    RoiThetaMaxEdit = uicontrol(RoiPanel, 'Style', 'edit', 'Units', 'normalized', 'String', sprintf('%.2f', RoiThetaRange(2)), 'Position', [0.72, 0.77, 0.18, 0.06]);
    uicontrol(RoiPanel, 'Style', 'text', 'String', 'Threshold [dBi]', 'Units', 'normalized', 'HorizontalAlignment', 'left', 'Position', [0.08, 0.68, 0.42, 0.06]);
    RoiThresholdEdit = uicontrol(RoiPanel, 'Style', 'edit', 'Units', 'normalized', 'String', sprintf('%.2f', RoiThreshold), 'Position', [0.50, 0.68, 0.40, 0.06]);
    RoiButton = uicontrol(RoiPanel, 'Style', 'pushbutton', 'String', '更新区域统计', 'Units', 'normalized', 'FontWeight', 'bold', 'Position', [0.08, 0.58, 0.82, 0.07]);
    RoiResultText = uicontrol(RoiPanel, 'Style', 'text', 'Units', 'normalized', 'HorizontalAlignment', 'left', 'FontName', 'Consolas', 'FontSize', 9, 'String', '', 'Position', [0.08, 0.04, 0.84, 0.50]);

    MarkerHandle = []; 
    TextHandle = []; 
    RoiHandles = gobjects(1, 5); % 初始化空句柄消除动态扩容警告

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

    function OnSliderChanged(~, ~)
        PhiVal = get(PhiSlider, 'Value'); 
        ThetaVal = get(ThetaSlider, 'Value');
        set(PhiEdit, 'String', sprintf('%.2f', PhiVal)); 
        set(ThetaEdit, 'String', sprintf('%.2f', ThetaVal));
        UpdateQuery(PhiVal, ThetaVal);
    end

    function OnEditChanged(~, ~)
        PhiVal = str2double(get(PhiEdit, 'String')); 
        ThetaVal = str2double(get(ThetaEdit, 'String'));
        if isnan(PhiVal), PhiVal = get(PhiSlider, 'Value'); end
        if isnan(ThetaVal), ThetaVal = get(ThetaSlider, 'Value'); end
        PhiVal = ClampLocal(PhiVal, PhiMin, PhiMax); 
        ThetaVal = ClampLocal(ThetaVal, ThetaMin, ThetaMax);
        set(PhiSlider, 'Value', PhiVal); 
        set(ThetaSlider, 'Value', ThetaVal);
        set(PhiEdit, 'String', sprintf('%.2f', PhiVal)); 
        set(ThetaEdit, 'String', sprintf('%.2f', ThetaVal));
        UpdateQuery(PhiVal, ThetaVal);
    end

    function OnViewModeChanged(~, ~)
        DrawBaseMap(); 
        UpdateQuery(get(PhiSlider, 'Value'), get(ThetaSlider, 'Value')); 
        UpdateRoiAnalysis();
    end

    function OnRoiChanged(~, ~)
        UpdateRoiAnalysis(); 
    end

    function DrawBaseMap()
        cla(Ax);
        if get(ViewModeCheckbox, 'Value') > 0
            pcolor(Ax, PhiGrid, ThetaGrid, GainGrid); 
            shading(Ax, 'interp'); 
            title(Ax, '伪彩色图 pcolor：Phi / Theta / Gain');
        else
            contourf(Ax, PhiGrid, ThetaGrid, GainGrid, 32, 'LineColor', 'none'); 
            hold(Ax, 'on');
            contour(Ax, PhiGrid, ThetaGrid, GainGrid, 32, 'LineColor', [0.15 0.15 0.15], 'LineStyle', '-', 'LineWidth', 0.35);
            title(Ax, '等高线图 contourf + 实线 contour：Phi / Theta / Gain');
        end
        hold(Ax, 'on'); grid(Ax, 'on'); colorbar(Ax); colormap(Ax, 'jet'); 
        xlabel(Ax, 'Phi [deg]'); ylabel(Ax, 'Theta [deg]');
        MarkerHandle = plot(Ax, NaN, NaN, 'rx', 'LineWidth', 2.5, 'MarkerSize', 12);
        TextHandle = text(Ax, NaN, NaN, '', 'Color', 'r', 'FontWeight', 'bold', 'BackgroundColor', 'w', 'Margin', 3);
        RoiHandles = gobjects(1, 5); 
    end

    function UpdateQuery(PhiVal, ThetaVal)
        GainVal = QueryGainLocal(PhiGrid, ThetaGrid, GainGrid, PhiVal, ThetaVal);
        set(MarkerHandle, 'XData', PhiVal, 'YData', ThetaVal);
        set(TextHandle, 'Position', [PhiVal, ThetaVal, 0], 'String', sprintf('  Phi=%.2f°, Theta=%.2f°, Gain=%.3f dBi', PhiVal, ThetaVal, GainVal));
        set(GainText, 'String', sprintf('当前 Gain = %.3f dBi', GainVal)); 
        drawnow;
    end

    function UpdateRoiAnalysis()
        PhiMinRoi = ClampLocal(ReadNumberLocal(RoiPhiMinEdit, RoiPhiRange(1)), PhiMin, PhiMax);
        PhiMaxRoi = ClampLocal(ReadNumberLocal(RoiPhiMaxEdit, RoiPhiRange(2)), PhiMin, PhiMax);
        ThetaMinRoi = ClampLocal(ReadNumberLocal(RoiThetaMinEdit, RoiThetaRange(1)), ThetaMin, ThetaMax);
        ThetaMaxRoi = ClampLocal(ReadNumberLocal(RoiThetaMaxEdit, RoiThetaRange(2)), ThetaMin, ThetaMax);
        ThresholdRoi = ReadNumberLocal(RoiThresholdEdit, RoiThreshold);

        set(RoiPhiMinEdit, 'String', sprintf('%.2f', PhiMinRoi)); 
        set(RoiPhiMaxEdit, 'String', sprintf('%.2f', PhiMaxRoi));
        set(RoiThetaMinEdit, 'String', sprintf('%.2f', ThetaMinRoi)); 
        set(RoiThetaMaxEdit, 'String', sprintf('%.2f', ThetaMaxRoi));
        set(RoiThresholdEdit, 'String', sprintf('%.2f', ThresholdRoi));

        RoiMask = PhiGrid >= min(PhiMinRoi, PhiMaxRoi) & PhiGrid <= max(PhiMinRoi, PhiMaxRoi) & ThetaGrid >= min(ThetaMinRoi, ThetaMaxRoi) & ThetaGrid <= max(ThetaMinRoi, ThetaMaxRoi) & ~isnan(GainGrid);
        GainValid = GainGrid(RoiMask);

        % 清理旧的 ROI 边界和文字句柄避免重叠堆积
        validHandles = isgraphics(RoiHandles);
        if any(validHandles)
            delete(RoiHandles(validHandles)); 
        end
        RoiHandles = gobjects(1, 5); 

        if isempty(GainValid)
            set(RoiResultText, 'String', '无有效数据'); 
            return;
        end

        [GainMax, MaxIdx] = max(GainValid); 
        [GainMin, MinIdx] = min(GainValid);
        ValidIdx = find(RoiMask); 
        [RowMax, ColMax] = ind2sub(size(GainGrid), ValidIdx(MaxIdx)); 
        [RowMin, ColMin] = ind2sub(size(GainGrid), ValidIdx(MinIdx));
        
        hold(Ax, 'on');
        RoiX = [min(PhiMinRoi, PhiMaxRoi), max(PhiMinRoi, PhiMaxRoi), max(PhiMinRoi, PhiMaxRoi), min(PhiMinRoi, PhiMaxRoi), min(PhiMinRoi, PhiMaxRoi)];
        RoiY = [min(ThetaMinRoi, ThetaMaxRoi), min(ThetaMinRoi, ThetaMaxRoi), max(ThetaMinRoi, ThetaMaxRoi), max(ThetaMinRoi, ThetaMaxRoi), min(ThetaMinRoi, ThetaMaxRoi)];
        
        % 消除警告：显式赋值到固定长度的 gobjects 数组
        h1 = plot(Ax, RoiX, RoiY, 'w--', 'LineWidth', 2.0);
        h2 = plot(Ax, PhiGrid(RowMax, ColMax), ThetaGrid(RowMax, ColMax), '^w', 'MarkerSize', 9, 'MarkerFaceColor', 'w', 'LineWidth', 1.2);
        h3 = text(Ax, PhiGrid(RowMax, ColMax), ThetaGrid(RowMax, ColMax), sprintf('  Max %.2f', GainMax), 'Color', 'w', 'FontSize', 8, 'FontWeight', 'bold');
        h4 = plot(Ax, PhiGrid(RowMin, ColMin), ThetaGrid(RowMin, ColMin), 'vy', 'MarkerSize', 9, 'MarkerFaceColor', 'y', 'LineWidth', 1.2);
        h5 = text(Ax, PhiGrid(RowMin, ColMin), ThetaGrid(RowMin, ColMin), sprintf('  Min %.2f', GainMin), 'Color', 'y', 'FontSize', 8, 'FontWeight', 'bold');
        
        RoiHandles = [h1, h2, h3, h4, h5];

        ResultString = sprintf('Points : %d\nMin    : %.3f dBi\nMean   : %.3f dBi\nMax    : %.3f dBi\nMedian : %.3f dBi\nStd    : %.3f dB\n> %.2f : %.2f %%\nPass   : %d', numel(GainValid), GainMin, mean(GainValid), GainMax, median(GainValid), std(GainValid), ThresholdRoi, 100 * mean(GainValid > ThresholdRoi), 100 * mean(GainValid > ThresholdRoi) >= 100);
        set(RoiResultText, 'String', ResultString);
    end
end

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