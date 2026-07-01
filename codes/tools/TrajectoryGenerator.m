function TrajectoryGenerator()
%==========================================================================
% TrajectoryGenerator
%
% 功能描述 (Description)
% -------------------------------------------------------------------------
% TrajectoryGenerator 用于生成标准目标运动轨迹（Trajectory），支持多种典型
% 飞行器/导弹运动模型，并导出标准 CSV 航迹文件，可用于目标仿真、雷达跟踪、
% 导引算法验证以及可视化分析。
%
% 支持的轨迹类型包括：
%   1. VerticalLaunch  垂直发射→转平飞
%   2. Turn            定半径压弯盘旋
%   3. Parabolic       抛物线弹道
%   4. S_Curve         S 型蛇形机动
%   5. LevelFlight     平飞直线
%
% 程序运行后通过 GUI 选择轨迹类型，自动计算目标运动状态，
% 最终输出两个 CSV 文件：
%   Trajectory_XXX.csv        - 平台位姿数据（经纬高 + 欧拉角）
%   AntennaTrajectory_XXX.csv - 天线局部指向角（Phi / Theta）
%
% 同时绘制三维飞行轨迹和天线局部球面打靶预览图。
%
%--------------------------------------------------------------------------
% 输入参数 (Input)无
%--------------------------------------------------------------------------
% 输出参数 (Output)无
%--------------------------------------------------------------------------
% 程序自动在
%
%   ../output/
%
% 目录下生成上述两个 CSV 文件。
%
% 平台数据字段：
%   Time_s, Lat_deg, Lon_deg, Alt_m, Yaw_deg, Pitch_deg, Roll_deg
%
% 天线指向数据字段：
%   Time_s, Phi_query_deg, Theta_query_deg
%   （Phi: 方位角，Theta: 天顶角，均在天线局部坐标系下）
%
%--------------------------------------------------------------------------
% 作者: linyi & gemni
% 创建日期: 2026-06-30
% 修改记录:
%   V1.1  2026-07-01  追加天线局部指向角计算模块，修复 Parabolic 等轨迹的
%                     数组索引越界问题，增强鲁棒性。
%==========================================================================

    clc; close all;
    
    %% 0. UI 交互
    trajList = {'1. VerticalLaunch (垂直发射转平飞)', ...
                '2. Turn (压弯盘旋)', ...
                '3. Parabolic (抛物线抛射/掉落)', ...
                '4. S_Curve (S型蛇形机动)', ...
                '5. LevelFlight (平飞直线)'};
                
    [indx, tf] = listdlg('PromptString', '选择弹道类型:', 'SelectionMode', 'single', ...
                         'ListSize', [300, 150], 'Name', '弹道生成器', 'ListString', trajList);
    if ~tf, return; end
    
    typeKeys = {'VerticalLaunch', 'Turn', 'Parabolic', 'S_Curve', 'LevelFlight'};
    TrajType = typeKeys{indx};

    %% 1. 物理参数
    dt = 0.1; t_end = 60; v0 = 300; h0 = 100;
    RefLat = 39.90; RefLon = 116.30;

    %% 2. 轨迹运动学计算（生成局部坐标系下的 x, y, z 以及欧拉角）
    t = (0 : dt : t_end)';
    n_pts = length(t);
    x = zeros(n_pts, 1); y = zeros(n_pts, 1); z = ones(n_pts, 1) * h0;
    yaw = zeros(n_pts, 1); pitch = zeros(n_pts, 1); roll = zeros(n_pts, 1);

    fprintf('>> 正在生成 [%s] 弹道...\n', TrajType);

    switch TrajType
        case 'VerticalLaunch'
            % 垂直发射 (0-5s) -> 压高过渡 (5-10s) -> 平飞 (10s+)
            % 初始化第一个点
            z(1) = h0; x(1) = 0; pitch(1) = 90;
            for i = 2:n_pts
                if t(i) < 5
                    z(i) = h0 + 0.5 * 50 * t(i)^2;   % 垂直加速
                    pitch(i) = 90;
                    x(i) = x(i-1);                    % 水平不动
                elseif t(i) < 10
                    % 线性压低仰角实现转弯
                    pct = (t(i)-5)/5;
                    pitch(i) = 90 * (1 - pct);
                    z(i) = z(i-1) + v0 * sind(pitch(i)) * dt;
                    x(i) = x(i-1) + v0 * cosd(pitch(i)) * dt;
                else
                    z(i) = z(i-1);                     % 保持平飞高度
                    x(i) = x(i-1) + v0 * dt;
                    pitch(i) = 0;
                end
            end

        case 'Turn'
            t_turn_start = 10; turn_rate = 5;
            omega_rad = deg2rad(turn_rate); g = 9.81;
            steady_roll = rad2deg(atan((v0 * omega_rad) / g));
            curr_yaw = 0; curr_x = 0; curr_y = 0;
            roll(1) = 0;  % 初始无横滚
            for i = 1:n_pts
                if t(i) >= t_turn_start
                    curr_yaw = curr_yaw + turn_rate * dt;
                    if i > 1
                        roll(i) = roll(i-1) + (steady_roll - roll(i-1)) * 0.1;
                    else
                        roll(i) = steady_roll;  % 若第一帧就进入转弯，直接置稳态
                    end
                end
                curr_x = curr_x + v0 * dt * cosd(curr_yaw);
                curr_y = curr_y + v0 * dt * sind(curr_yaw);
                x(i) = curr_x; y(i) = curr_y; yaw(i) = curr_yaw;
            end
            
        case 'Parabolic'
            g = 9.81; gamma0 = 15;
            vx = v0 * cosd(gamma0); vz = v0 * sind(gamma0);
            x = vx .* t; 
            z = h0 + vz .* t - 0.5 * g .* t.^2;
            pitch = atand((vz - g .* t) ./ vx);
            % y 保持为 0，初始 y 为 0
            y = zeros(size(t));
            % 限制高度不小于 0（触地截断）
            stop_idx = find(z < 0, 1);
            if ~isempty(stop_idx)
                idx = 1:stop_idx;
                t = t(idx); x = x(idx); y = y(idx); z = z(idx);
                pitch = pitch(idx); yaw = yaw(idx); roll = roll(idx);
            end
            
        case 'S_Curve'
            omega_s = 2 * pi / 20; max_yaw_rate = 10; g = 9.81;
            curr_x = 0; curr_y = 0;
            roll(1) = 0;  % 初始横滚为 0
            for i = 1:n_pts
                cur_rate = max_yaw_rate * sin(omega_s * t(i));
                if i > 1
                    yaw(i) = yaw(i-1) + cur_rate * dt;
                    roll(i) = rad2deg(atan((v0 * deg2rad(cur_rate)) / g)) * 0.5;
                else
                    yaw(i) = 0;
                    roll(i) = 0;
                end
                curr_x = curr_x + v0 * dt * cosd(yaw(i));
                curr_y = curr_y + v0 * dt * sind(yaw(i));
                x(i) = curr_x; y(i) = curr_y;
            end
            
        case 'LevelFlight'
            x = v0 .* t;
            y = zeros(size(t));
            pitch(:) = 0; yaw(:) = 0; roll(:) = 0;
    end

    %% 3. 标准化输出（平台数据：经纬高 + 欧拉角）
    Re = 6378137;
    lat = RefLat + rad2deg(x ./ Re);
    lon = RefLon + rad2deg(y ./ (Re .* cosd(RefLat)));
    
    outTable = table(t, lat, lon, z, yaw, pitch, roll, ...
        'VariableNames', {'Time_s', 'Lat_deg', 'Lon_deg', 'Alt_m', 'Yaw_deg', 'Pitch_deg', 'Roll_deg'});

    outDir = fullfile(fileparts(mfilename('fullpath')), '..', 'output');
    if ~exist(outDir, 'dir'), mkdir(outDir); end
    
    savePath = fullfile(outDir, sprintf('Trajectory_%s.csv', TrajType));
    writetable(outTable, savePath);
    fprintf('>> 平台轨迹导出成功: %s\n', savePath);

    %% 4. 三维轨迹绘图（经纬高）
    figure('Name', ['轨迹 3D 靶场 - ', TrajType], 'Color', 'w');
    plot3(lon, lat, z, 'k-', 'LineWidth', 1.5); grid on;
    xlabel('经度 (deg)'); ylabel('纬度 (deg)'); zlabel('高度 (m)');
    title(['弹道预览: ', TrajType]);

    %% ========= 新增模块 ===================================================
    %% 5. 天线局部指向角轨迹解算（Phi / Theta）
    % 将平台位姿（x,y,z,yaw,pitch,roll）转换为天线局部球坐标系指向角
    % 假设目标（如地面站/接收机）位于局部坐标系原点 [0, 0, 0]
    target_pos = [0, 0, 0];  % 若目标不是原点，请在此修改

    fprintf('>> 正在解算天线局部指向角（目标位于原点）...\n');

    % 预分配数组
    Phi_query = zeros(length(t), 1);
    Theta_query = zeros(length(t), 1);

    for i = 1:length(t)
        % Step 1: 全局视线向量（从平台指向目标）
        r_global = target_pos' - [x(i); y(i); z(i)];
        
        % Step 2: 构建本体旋转矩阵（Z-Y-X 内旋，对应 Yaw-Pitch-Roll）
        cy = cosd(yaw(i));   sy = sind(yaw(i));
        cp = cosd(pitch(i)); sp = sind(pitch(i));
        cr = cosd(roll(i));  sr = sind(roll(i));
        
        % Z-Y-X 旋转矩阵 (R = Rz * Ry * Rx)
        R = [cy*cp,  cy*sp*sr - sy*cr,  cy*sp*cr + sy*sr;
             sy*cp,  sy*sp*sr + cy*cr,  sy*sp*cr - cy*sr;
             -sp,    cp*sr,             cp*cr];
         
        % Step 3: 将视线向量转换到天线本体局部坐标系（转置旋转矩阵 = 全局->局部）
        r_local = R' * r_global;
        
        % Step 4: 局部笛卡尔坐标 -> 球面角（天线工程标准定义）
        r_norm = norm(r_local);
        if r_norm < 1e-6
            Theta_query(i) = 0;
            Phi_query(i) = 0;
            continue;
        end
        
        % Theta：与局部 +Z 轴的夹角（0° 朝天顶，90° 朝侧向，180° 朝尾部）
        Theta_query(i) = rad2deg(acos( r_local(3) / r_norm ));
        % Phi：在 X-Y 平面与 +X 轴的夹角（-180° ~ 180°）
        Phi_query(i) = rad2deg(atan2( r_local(2), r_local(1) ));
    end

    % Step 5: 导出天线指向轨迹专用 CSV
    antTable = table(t, Phi_query, Theta_query, ...
        'VariableNames', {'Time_s', 'Phi_query_deg', 'Theta_query_deg'});
    antSavePath = fullfile(outDir, sprintf('AntennaTrajectory_%s.csv', TrajType));
    writetable(antTable, antSavePath);
    fprintf('>> 天线指向轨迹导出成功: %s\n', antSavePath);

    % Step 6: 绘制天线指向角的二维打靶预览图
    figure('Name', ['天线局部球面打靶预览 - ', TrajType], 'Color', 'w');
    scatter(Phi_query, Theta_query, 10, 'filled', 'MarkerFaceColor', [0.2 0.4 0.8]);
    xlabel('Phi 方位角 (deg)'); ylabel('Theta 天顶角 (deg)');
    title(sprintf('天线局部坐标系指向散点图 (点数: %d)', length(t)));
    grid on; axis equal; xlim([-180 180]); ylim([0 180]);
    set(gca, 'YDir', 'reverse');  % 让天顶角 0° 在顶部，符合方向图阅读习惯

    fprintf('>> 全部生成完成！\n');
end