%% main_link_top.m
% 通信链路仿真与天线约束分析系统主控平台
%
% 语法 (Syntax):
%   运行 main_link_top.m
%
% 描述 (Description):
%   本程序为链路仿真系统的顶层调度中心 (TOP Layer)。运行后首先唤起强焦点 UI 交互菜单，
%   由用户动态选择“Tx单端打靶验证”、“Rx单端打靶验证”或“执行全链路时间序列大演习仿真”。
%   程序自动加载外部 W365 剧本表 (Scenario_Config.xlsx) 精准覆盖姿态安装偏角，
%   核心链路基于 Local XYZ 局部空间坐标，解耦调用场景加载、3D几何计算、
%   双端动态天线增益查表查阵、链路预算及全自动工程图表可视化产出。
%
% 输入参数 (Inputs - 统一集成于 simCfgIn 顶层配置结构体中):
%   simCfgIn.scenarioName      - [String]  当前仿真场景业务名称
%   simCfgIn.inputMode         - [String]  场景轨迹输入模式 ('synthetic' 仿真 / 'real' 读轨)
%   simCfgIn.f                 - [Double]  电磁波工作频率 (单位: Hz)
%   simCfgIn.Pt                - [Double]  发射机天线前端输入功率 (单位: dBm)
%   simCfgIn.Sens              - [Double]  接收机功放解调标称灵敏度门限 (单位: dBm)
%   simCfgIn.L_other           - [Double]  极化、雨衰、馈线等综合系统附加损耗 (单位: dB)
%   simCfgIn.Margin_target     - [Double]  评判链路达标的最低标称设计余量阈值 (单位: dB)
%   simCfgIn.txPatternFile     - [String]  Tx 辐射方向图 CSV 文件绝对/相对路径
%   simCfgIn.rxPatternFile     - [String]  Rx 辐射方向图 CSV 文件绝对/相对路径
%   simCfgIn.txAngleMap        - [Struct]  Tx 方向图球坐标系对其与轴向映射适配字典
%   simCfgIn.rxAngleMap        - [Struct]  Rx 方向图球坐标系对其与轴向映射适配字典
%
% 输出产物 (Outputs - 动态挂载于仿真核心回传句柄中):
%   LinkResult.Gt / .Gr        - [N x 1]   全时序发射端、接收端天线查表动态增益向量 (dBi)
%   LinkResult.Az_query_tx     - [N x 1]   包含三轴偏角影响后实际检索 Tx 方向图的 Phi 方位角序列
%   LinkResult.El_query_tx     - [N x 1]   包含三轴偏角影响后实际检索 Tx 方向图的 Theta 天顶角序列
%   AnalysisResult.Summary     - [Struct]  全动态航线下的最小链路余量 (Margin_min) 等关键指标统计
%   Figure(100~500)            - [Window]  动态弹出的 3D 轨迹图、余量时序图、视角热力热图、打靶检查图
%
% 核心原则 (Core Architecture Rules):
%   1) 核心链路仿真只使用 local XYZ 坐标。
%   2) 距离 d 必须由 Tx/Rx 坐标计算得到，不允许作为输入直接赋值。
%   3) GPS/WGS84 仅作为 tools 中的可选预处理工具，不进入核心链路预算内核。
%   4) TOP 层不写核心逻辑，只负责调用各模块与 UI 菜单路由引流。
%
% 作者: 林怡 & Gemmi
% 版本: Release V3.0.0 (Zero-Warning) - 融合强焦点 UI 智能可选框与双端打靶保护闭环版
% =========================================================================

clear; clc; close all;

%% 0. 工程路径重构与环境动态挂载
rootDir = fileparts(mfilename('fullpath'));
addpath(rootDir);
addpath(fullfile(rootDir, 'config'));
addpath(fullfile(rootDir, 'io'));
addpath(fullfile(rootDir, 'core'));
addpath(fullfile(rootDir, 'core', 'geometry'));
addpath(fullfile(rootDir, 'core', 'antenna'));
addpath(fullfile(rootDir, 'core', 'linkbudget'));
addpath(fullfile(rootDir, 'plot'));

fprintf('\n========== main_link_top ==========\n');
fprintf('工程主控目录: %s\n', rootDir);
fprintf('===================================\n\n');

%% 1. 用户参数配置区
simCfgIn = struct();
simCfgIn.scenarioName = 'tc06_realistic_local_xyz';
simCfgIn.inputMode = 'synthetic';
simCfgIn.enablePlot = true;
simCfgIn.saveFigure = true;

% 4.95GHz 核心射频指标硬调区
simCfgIn.f = 4.95e9;
simCfgIn.Pt = 20;
simCfgIn.Sens = -90;
simCfgIn.L_other = 0;
simCfgIn.Margin_target = 3;

% 天线底层文件引擎重构路由
simCfgIn.txAntennaType = 'pattern';
simCfgIn.rxAntennaType = 'pattern';
simCfgIn.txPatternSource = 'csv';
simCfgIn.rxPatternSource = 'csv';
simCfgIn.txPatternFile = fullfile(rootDir, 'input', 'tx_antenna_pattern.csv');
simCfgIn.rxPatternFile = fullfile(rootDir, 'input', 'rx_antenna_pattern.csv');
simCfgIn.angleInputType = 'PhiTheta';

% --- 【核心映射轴向对齐字典】 ---
% Tx 角度映射
simCfgIn.txAngleMap.phiOffsetDeg = 270;
simCfgIn.txAngleMap.thetaMode = 'identity'; 

% Rx 角度映射
simCfgIn.rxAngleMap.phiOffsetDeg = 0;
simCfgIn.rxAngleMap.thetaMode = 'zenith0_horizon90';
% ---------------------------------

%% ========================================================================
% 🌟 2. 【全新强焦点交互可选框拦截总控】：运行后强制弹窗，控御单双端行为
% ========================================================================
UiMenuOptions = { ...
    '1. 运行完整链路动态大仿真 (同时计算Tx/Rx全时序曲线)', ...
    '2. 仅看 Tx 发射端天线角度变换 (快速打靶散点模式)', ...
    '3. 仅看 Rx 接收端天线角度变换 (快速打靶散点模式)'};

SelectedModeIdx = menu('请选择本次大系统演习运行模式：', UiMenuOptions);

if SelectedModeIdx == 0
    fprintf('💡 提示: 您取消了菜单，主控台默认安全切入【1. 完整链路大仿真】。\n');
    SelectedModeIdx = 1;
end
% ========================================================================

%% 3. 系统参数初始化与外部剧本覆盖
[SimCfg, GeoCfg, RfCfg, AntCfg, AlgoCfg, OutCfg, CfgDiag] = linkInitConfig(simCfgIn);

% 【安全外推边界保护协议】：杜绝查表出边界导致的负无穷大 -100 dBi 穿模
AntCfg.tx.outOfBound = 'extrapolate';
AntCfg.rx.outOfBound = 'extrapolate';

% 联动 W365 大系统剧本配置自动注入
configPath = fullfile(rootDir, 'input', 'Scenario_Config.xlsx');
if exist(configPath, 'file')
    AntCfg = loadConfigFromExcel(configPath, AntCfg);
    fprintf('成功：已无损挂载外部 Excel 姿态字典参数。\n');
else
    fprintf('提示：未发现外部 Excel 配置文件，安全激活硬件默认零偏角姿态。\n');
end

%% 4. 方向图实体文件存在性物理熔断器
if strcmpi(AntCfg.tx.type, 'pattern')
    assert(exist(AntCfg.tx.patternFile, 'file') == 2, 'Tx 熔断报错: 方向图文件丢失: %s', AntCfg.tx.patternFile);
end
if strcmpi(AntCfg.rx.type, 'pattern')
    assert(exist(AntCfg.rx.patternFile, 'file') == 2, 'Rx 熔断报错: 方向图文件丢失: %s', AntCfg.rx.patternFile);
end

%% 5. 核心仿真流水线车间
% 调度数据加载车间
[TxNode, RxNode, AntTx, AntRx, InputDiag] = linkLoadOneScenario(SimCfg, GeoCfg, AntCfg);

% 调度核心物理仿真车间 (在这里会执行全时序的双核并行 3D 旋转计算)
[LinkResult, SimDiag] = linkSimOneScenario(TxNode, RxNode, AntTx, AntRx, GeoCfg, RfCfg, AntCfg, AlgoCfg);

% 调度统计数据析取车间
[AnalysisResult, AnalysisDiag] = linkAnalyzeOneScenario(LinkResult, RfCfg, AlgoCfg);

%% 6. 可视化报告车间调度控制路由 (根据可选框点击结果进行引流分道分流)
if SelectedModeIdx == 1
    % 【全链路大仿真模式】：执行完整大系统画图，渲染余量时序和3D动态轨迹
    [OutInfo, OutDiag] = linkOutputOneScenario(LinkResult, AnalysisResult, SimCfg, GeoCfg, RfCfg, AntCfg, OutCfg);
    
    fprintf('\n==== 链路动态仿真完成：%s ====\n', SimCfg.scenarioName);
    fprintf('最小链路安全余量 Margin_min : %.2f dB\n', AnalysisResult.Summary.minMargin);
    fprintf('物理分析产物输出目录: %s\n\n', OutInfo.outputDir);
end

%% 7. 显微检查画板：精准捕捉并渲染打靶查询数据范围 (0 警告显式坐标轴升级)
if SelectedModeIdx == 1 || SelectedModeIdx == 2
    % 激活或者单测 Tx 检查画板
    FigTxCheck = figure('Name', 'Tx 天线打靶重构映射分布检查', 'Color', 'w');
    AxTxCheck = axes('Parent', FigTxCheck);
    scatter(AxTxCheck, LinkResult.Az_query_tx, LinkResult.El_query_tx, 20, LinkResult.Gt, 'filled');
    xlabel(AxTxCheck, '发射端天线查询方位角 Tx Phi [deg]'); 
    ylabel(AxTxCheck, '发射端天线查询天顶角 Tx Theta [deg]'); 
    title(AxTxCheck, sprintf('Tx 空间映射落点图 (已融合安装姿态角影响, 数据点数: %d)', numel(LinkResult.Gt))); 
    ColorBarTx = colorbar(AxTxCheck); ColorBarTx.Label.String = '增益 Realized Gain (dBi)';
    colormap(AxTxCheck, jet); grid(AxTxCheck, 'on');
    
    fprintf('Tx 打靶查询域核对: Phi [%.2f, %.2f]° , Theta [%.2f, %.2f]°\n', ...
        min(LinkResult.Az_query_tx), max(LinkResult.Az_query_tx), ...
        min(LinkResult.El_query_tx), max(LinkResult.El_query_tx));
end

if SelectedModeIdx == 1 || SelectedModeIdx == 3
    % 激活或者单测 Rx 检查画板
    FigRxCheck = figure('Name', 'Rx 天线打靶重构映射分布检查', 'Color', 'w');
    AxRxCheck = axes('Parent', FigRxCheck);
    scatter(AxRxCheck, LinkResult.Az_query_rx, LinkResult.El_query_rx, 20, LinkResult.Gr, 'filled');
    xlabel(AxRxCheck, '接收端天线查询方位角 Rx Phi [deg]'); 
    ylabel(AxRxCheck, '接收端天线查询仰角/天顶角 Rx Theta [deg]'); 
    title(AxRxCheck, sprintf('Rx 空间映射落点图 (已融合安装姿态角影响, 数据点数: %d)', numel(LinkResult.Gr))); 
    ColorBarRx = colorbar(AxRxCheck); ColorBarRx.Label.String = '增益 Realized Gain (dBi)';
    colormap(AxRxCheck, jet); grid(AxRxCheck, 'on');
    
    fprintf('Rx 打靶查询域核对: Phi [%.2f, %.2f]° , Theta [%.2f, %.2f]°\n', ...
        min(LinkResult.Az_query_rx), max(LinkResult.Az_query_rx), ...
        min(LinkResult.El_query_rx), max(LinkResult.El_query_rx));
end

fprintf('\n====== main_link_top 执行流完美结束 ======\n\n');