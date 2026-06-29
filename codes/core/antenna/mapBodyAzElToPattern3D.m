function [PatternPhiDeg, PatternThetaDeg] = mapBodyAzElToPattern3D(BodyAzDeg, BodyElDeg, MountYawDeg, MountPitchDeg, MountRollDeg)
% =========================================================================
% 函数名称 (Function): mapBodyAzElToPattern3D
% 
% 语法 (Syntax):
%   [PatternPhiDeg, PatternThetaDeg] = mapBodyAzElToPattern3D(BodyAzDeg, BodyElDeg, MountYawDeg, MountPitchDeg, MountRollDeg)
%
% 描述 (Description):
%   将机体相对坐标系下的目标方位/俯仰角，结合天线安装偏角 (Yaw/Pitch/Roll)，
%   运用纯数学三维欧拉角(Z-Y-X)逆矩阵，严谨映射为天线本体的 Phi/Theta 球坐标。
%   支持大规模 N×1 时间序列动态数组的并行矩阵运算。
%
% 输入参数 (Inputs):
%   BodyAzDeg     - [N x 1 Double] 目标在当前机体坐标系下的方位角 (单位: 度)
%   BodyElDeg     - [N x 1 Double] 目标在当前机体坐标系下的俯仰角 (单位: 度)
%   MountYawDeg   - [Double] 天线安装偏航角 (绕机体 Z 轴，正值向左偏航，单位: 度)
%   MountPitchDeg - [Double] 天线安装俯仰角 (绕机体 Y 轴，负值机头下压，单位: 度)
%   MountRollDeg  - [Double] 天线安装横滚角 (绕机体 X 轴，正值右侧翻，单位: 度)
%
% 输出参数 (Outputs):
%   PatternPhiDeg   - [N x 1 Double] 映射到天线本体 3D 方向图中的方位角 Phi (范围: 0~360度)
%   PatternThetaDeg - [N x 1 Double] 映射到天线本体 3D 方向图中的天顶角 Theta (范围: 0~180度)
%
% 作者: 林怡 & gemmi
% 版本: Release V2.1 (带标准 I/O 字典说明的终极版)
% =========================================================================

    % 1. 将输入的机体相对角度转为弧度 (拉平为行向量，支持动态数组并行处理)
    AzRad = deg2rad(BodyAzDeg(:)');
    ElRad = deg2rad(BodyElDeg(:)');

    % 2. 转换为机体坐标系下的 3D 空间单位向量
    % (X为正前方，Y为左侧，Z为正上方，完全符合球坐标物理投影定义)
    X_body = cos(ElRad) .* cos(AzRad);
    Y_body = cos(ElRad) .* sin(AzRad);
    Z_body = sin(ElRad);
    
    % 将向量按列拼接成 3 x N 的时间序列计算矩阵
    V_body = [X_body; Y_body; Z_body];

    % 3. 构造天线安装的绝对旋转矩阵 (Z-Y-X 标准航空航天欧拉角顺序)
    Alpha = deg2rad(MountYawDeg);
    Beta  = deg2rad(MountPitchDeg);
    Gamma = deg2rad(MountRollDeg);

    Rz = [cos(Alpha), -sin(Alpha), 0; sin(Alpha), cos(Alpha), 0; 0, 0, 1];
    Ry = [cos(Beta),  0, sin(Beta);   0, 1, 0;          -sin(Beta), 0, cos(Beta)];
    Rx = [1, 0, 0;            0, cos(Gamma), -sin(Gamma); 0, sin(Gamma), cos(Gamma)];

    % 获得天线相对于机体的姿态旋转总矩阵 R_mount
    R_mount = Rz * Ry * Rx;

    % 【核心物理逻辑】
    % 因为我们要拿着机体视线去找天线方向图的坐标，这是一个“坐标系逆变换”查询过程。
    % 根据正交矩阵特性，逆矩阵即为转置矩阵 (Transpose)。
    R_body_to_ant = R_mount';

    % 4. 矩阵批量并行乘法：瞬间求出每一秒钟天线坐标系下的 3D 向量
    V_ant = R_body_to_ant * V_body;

    X_ant = V_ant(1, :);
    Y_ant = V_ant(2, :);
    Z_ant = V_ant(3, :);

    % 5. 提取天线本体球坐标系下的天顶角 Theta 和 方位角 Phi
    PatternThetaRad = acos(Z_ant);
    PatternPhiRad   = atan2(Y_ant, X_ant);

    % 6. 还原回角度，并恢复与主系统输入完全一致的 Nx1 数组形状
    PatternThetaDeg = reshape(rad2deg(PatternThetaRad), size(BodyAzDeg));
    PatternPhiDeg   = reshape(mod(rad2deg(PatternPhiRad), 360), size(BodyAzDeg));
    
end