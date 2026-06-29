function [AntSeries, AntDiag] = linkCalcAntennaGainSeries(GeoSeries, AntTx, AntRx, AntCfg)
% =========================================================================
% 函数名称 (Function): linkCalcAntennaGainSeries
% 
% 语法 (Syntax):
%   [AntSeries, AntDiag] = linkCalcAntennaGainSeries(GeoSeries, AntTx, AntRx, AntCfg)
%
% 描述 (Description):
%   大系统时间序列 Tx/Rx 双端天线增益动态查表核心。
%   自动读取主配置，针对全时间序列 N 个飞行点，独立调用底层 3D 旋转矩阵，
%   分别对 Tx 和 Rx 进行静默的几何映射与高精度插值查表，严禁使用任何阻塞式 UI。
%
% 输入参数 (Inputs):
%   GeoSeries - [Struct] 包含全时间序列和动态相对几何视角的结构体：
%       .t     - [N x 1 Double] 动态时间戳序列 (秒)
%       .Az_tx / .El_tx - [N x 1 Double] 发射端(Tx)机体视角的方位角/俯仰角序列
%       .Az_rx / .El_rx - [N x 1 Double] 接收端(Rx)机体视角的方位角/俯仰角序列
%   AntTx     - [Struct] 发射天线的 3D 辐射方向图解析数据 (含网格增益矩阵等)
%   AntRx     - [Struct] 接收天线的 3D 辐射方向图解析数据 (含网格增益矩阵等)
%   AntCfg    - [Struct] 天线链路配置结构体 (包含 .tx 与 .rx 的独立安装姿态角等)
%
% 输出参数 (Outputs):
%   AntSeries - [Struct] 封装了全时序下双端动态增益与映射坐标：
%       .Gt / .Gr - [N x 1 Double] 发射端和接收端的天线动态增益序列 (dB)
%       .Gtotal_actual - [N x 1 Double] Tx 与 Rx 增益时间序列之和
%   AntDiag   - [Struct] 链路增益计算诊断日志与健康度统计：
%       .Gt_mean / .Gr_mean - 平均增益统计
%       .TxOutOfBoundCount / .RxOutOfBoundCount - 越界脱靶点计数
%
% 作者: linyi & gemmi
% 版本: Release V2.1 (完善标准 I/O 字典文档)
% =========================================================================

    N = numel(GeoSeries.t);

    % 提取动态几何计算出的视线角度
    Az_tx = GeoSeries.Az_tx(:);
    El_tx = GeoSeries.El_tx(:);
    Az_rx = GeoSeries.Az_rx(:);
    El_rx = GeoSeries.El_rx(:);

    Gt = zeros(N, 1);
    Gr = zeros(N, 1);

    % 初始化查表真实查询坐标存储器
    Az_query_tx = nan(N, 1);
    El_query_tx = nan(N, 1);
    Az_query_rx = nan(N, 1);
    El_query_rx = nan(N, 1);

    %% ==========================================
    %% 第一核：全量计算 Tx 发射天线动态增益
    %% ==========================================
    if strcmpi(AntCfg.tx.type, 'omni')
        Gt(:) = AntCfg.tx.omni_gain_dbi;
    else
        % 1. 安全提取 Tx 的 3D 安装偏角 (已与 Excel 联动)
        MountYawTx   = getOptLocal(AntCfg.tx.angleMap, 'MountYawDeg', 0);
        MountPitchTx = getOptLocal(AntCfg.tx.angleMap, 'MountPitchDeg', 0);
        MountRollTx  = getOptLocal(AntCfg.tx.angleMap, 'MountRollDeg', 0);

        % 2. 调用核心物理 3D 旋转映射矩阵
        [TruePhi_tx, TrueTheta_tx] = mapBodyAzElToPattern3D(Az_tx, El_tx, MountYawTx, MountPitchTx, MountRollTx);

        % 3. 传入 CSV 角度适配器 (处理 identity 等极坐标系对其问题)
        [Az_query_tx, El_query_tx] = mapBodyAzElToPatternAngle(TruePhi_tx, TrueTheta_tx, AntCfg.tx.angleMap);

        % 4. 2D 散点/网格插值查表获取每一秒的最终增益 dB
        Gt = getAntennaGain( ...
            Az_query_tx, El_query_tx, ...
            AntTx.Az_grid, AntTx.El_grid, AntTx.Gain_grid, ...
            AntTx.interpolation, AntTx.outOfBound);
    end

    %% ==========================================
    %% 第二核：全量计算 Rx 接收天线动态增益
    %% ==========================================
    if strcmpi(AntCfg.rx.type, 'omni')
        Gr(:) = AntCfg.rx.omni_gain_dbi;
    else
        % 1. 安全提取 Rx 的 3D 安装偏角
        MountYawRx   = getOptLocal(AntCfg.rx.angleMap, 'MountYawDeg', 0);
        MountPitchRx = getOptLocal(AntCfg.rx.angleMap, 'MountPitchDeg', 0);
        MountRollRx  = getOptLocal(AntCfg.rx.angleMap, 'MountRollDeg', 0);

        % 2. 调用核心物理 3D 旋转映射矩阵
        [TruePhi_rx, TrueTheta_rx] = mapBodyAzElToPattern3D(Az_rx, El_rx, MountYawRx, MountPitchRx, MountRollRx);

        % 3. 传入 CSV 角度适配器
        [Az_query_rx, El_query_rx] = mapBodyAzElToPatternAngle(TruePhi_rx, TrueTheta_rx, AntCfg.rx.angleMap);

        % 4. 获取最终增益
        Gr = getAntennaGain( ...
            Az_query_rx, El_query_rx, ...
            AntRx.Az_grid, AntRx.El_grid, AntRx.Gain_grid, ...
            AntRx.interpolation, AntRx.outOfBound);
    end

    %% 最终输出封装模块
    AntSeries = struct();
    AntSeries.Gt = Gt;
    AntSeries.Gr = Gr;
    AntSeries.Gtotal_actual = Gt + Gr;

    % 原始机体视线角
    AntSeries.Az_body_tx = Az_tx;
    AntSeries.El_body_tx = El_tx;
    AntSeries.Az_body_rx = Az_rx;
    AntSeries.El_body_rx = El_rx;

    % 实际查询 CSV 的球坐标角
    AntSeries.Az_query_tx = Az_query_tx;
    AntSeries.El_query_tx = El_query_tx;
    AntSeries.Az_query_rx = Az_query_rx;
    AntSeries.El_query_rx = El_query_rx;

    % 兼容底层变量命名规范
    AntSeries.Phi_tx = Az_query_tx;
    AntSeries.Theta_tx = El_query_tx;
    AntSeries.Phi_rx = Az_query_rx;
    AntSeries.Theta_rx = El_query_rx;

    %% 控制台诊断与统计分析数据打印
    AntDiag = struct();
    AntDiag.message = '大系统天线增益查表完成 (3D 矩阵严谨映射版)。';

    AntDiag.Gt_min = min(Gt); AntDiag.Gt_max = max(Gt); AntDiag.Gt_mean = mean(Gt);
    AntDiag.Gr_min = min(Gr); AntDiag.Gr_max = max(Gr); AntDiag.Gr_mean = mean(Gr);
    AntDiag.Gtotal_min = min(Gt + Gr); AntDiag.Gtotal_max = max(Gt + Gr); AntDiag.Gtotal_mean = mean(Gt + Gr);

    AntDiag.interpolation = AntCfg.interpolation;
    AntDiag.outOfBound = AntCfg.outOfBound;
    AntDiag.TxOutOfBoundCount = sum(Gt <= AntCfg.outOfBound);
    AntDiag.RxOutOfBoundCount = sum(Gr <= AntCfg.outOfBound);

    fprintf('\n========== linkCalcAntennaGainSeries ==========\n');
    fprintf('Tx Gt 范围: %6.3f ~ %6.3f dBi, 平均 %6.3f dBi\n', AntDiag.Gt_min, AntDiag.Gt_max, AntDiag.Gt_mean);
    fprintf('Rx Gr 范围: %6.3f ~ %6.3f dBi, 平均 %6.3f dBi\n', AntDiag.Gr_min, AntDiag.Gr_max, AntDiag.Gr_mean);
    fprintf('Gt+Gr 范围: %6.3f ~ %6.3f dBi, 平均 %6.3f dBi\n', AntDiag.Gtotal_min, AntDiag.Gtotal_max, AntDiag.Gtotal_mean);
    fprintf('Tx 信号脱靶越界点数: %d / %d\n', AntDiag.TxOutOfBoundCount, N);
    fprintf('Rx 信号脱靶越界点数: %d / %d\n', AntDiag.RxOutOfBoundCount, N);
    fprintf('================================================\n\n');
end

%% 本地辅助函数：安全获取结构体字段
function val = getOptLocal(S, field, defaultVal)
    if isfield(S, field)
        val = S.(field);
    else
        val = defaultVal;
    end
end