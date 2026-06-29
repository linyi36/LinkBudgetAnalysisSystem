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
% 最终输出标准轨迹 CSV 文件，并绘制三维飞行轨迹。
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
% 目录下生成：
%
%   Trajectory_XXX.csv
%
% 输出字段包括：
%
%   Time_s      时间(s)
%   Lat_deg     纬度(deg)
%   Lon_deg     经度(deg)
%   Alt_m       高度(m)
%   Yaw_deg     航向角(deg)
%   Pitch_deg   俯仰角(deg)
%   Roll_deg    横滚角(deg)
%
%--------------------------------------------------------------------------
% 轨迹模型 (Supported Trajectory Models)
%--------------------------------------------------------------------------
% VerticalLaunch
%     垂直起飞 → Pitch连续压低 → 平飞
%
% Turn
%     定速水平协调转弯
%
% Parabolic
%     初始俯仰角发射，自由抛体运动
%
% S_Curve
%     正弦变化航向角形成蛇形机动
%
% LevelFlight
%     匀速直线飞行
%
%--------------------------------------------------------------------------
% 作者 linyi& gemni
% 创建日期 (Created)
% 2026-06-30
%
%--------------------------------------------------------------------------
% 修改记录 (Revision History)
%--------------------------------------------------------------------------
% V1.0
%   - 初始版本
%   - 支持五种标准轨迹生成
%   - 支持CSV导出
%   - 支持三维轨迹可视化
%
%--------------------------------------------------------------------------
% 注意事项 (Notes)
%--------------------------------------------------------------------------
% 1. 所有角度单位均为 degree。
% 2. 时间单位为 second。
% 3. 高度单位为 meter。
% 4. 地理坐标采用球面近似转换。
% 5. 轨迹采样时间间隔默认为0.1 s。
%
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

    %% 2. 轨迹运动学计算
    t = (0 : dt : t_end)';
    n_pts = length(t);
    x = zeros(n_pts, 1); y = zeros(n_pts, 1); z = ones(n_pts, 1) * h0;
    yaw = zeros(n_pts, 1); pitch = zeros(n_pts, 1); roll = zeros(n_pts, 1);

    fprintf('>> 正在生成 [%s] 弹道...\n', TrajType);

    switch TrajType
        case 'VerticalLaunch'
            % 垂直发射 (0-5s) -> 压高过渡 (5-10s) -> 平飞 (10s+)
            for i = 1:n_pts
                if t(i) < 5
                    z(i) = h0 + 0.5 * 50 * t(i)^2; % 垂直加速
                    pitch(i) = 90;
                elseif t(i) < 10
                    % 线性压低仰角实现转弯
                    pct = (t(i)-5)/5;
                    pitch(i) = 90 * (1 - pct);
                    z(i) = z(i-1) + v0 * sind(pitch(i)) * dt;
                    x(i) = x(i-1) + v0 * cosd(pitch(i)) * dt;
                else
                    z(i) = z(i-1); % 保持平飞高度
                    x(i) = x(i-1) + v0 * dt;
                    pitch(i) = 0;
                end
            end

        case 'Turn'
            t_turn_start = 10; turn_rate = 5;
            omega_rad = deg2rad(turn_rate); g = 9.81;
            steady_roll = rad2deg(atan((v0 * omega_rad) / g));
            curr_yaw = 0; curr_x = 0; curr_y = 0;
            for i = 1:n_pts
                if t(i) >= t_turn_start
                    curr_yaw = curr_yaw + turn_rate * dt;
                    if i > 1, roll(i) = roll(i-1) + (steady_roll - roll(i-1)) * 0.1; end
                end
                curr_x = curr_x + v0 * dt * cosd(curr_yaw);
                curr_y = curr_y + v0 * dt * sind(curr_yaw);
                x(i) = curr_x; y(i) = curr_y; yaw(i) = curr_yaw;
            end
            
        case 'Parabolic'
            g = 9.81; gamma0 = 15;
            vx = v0 * cosd(gamma0); vz = v0 * sind(gamma0);
            x = vx .* t; z = h0 + vz .* t - 0.5 * g .* t.^2;
            pitch = atand((vz - g .* t) ./ vx);
            stop_idx = find(z < 0, 1);
            if ~isempty(stop_idx)
                idx = 1:stop_idx;
                t = t(idx); x = x(idx); y = y(idx); z = z(idx);
                yaw = yaw(idx); pitch = pitch(idx); roll = roll(idx);
            end
            
        case 'S_Curve'
            omega_s = 2 * pi / 20; max_yaw_rate = 10; g = 9.81;
            curr_x = 0; curr_y = 0;
            for i = 1:n_pts
                cur_rate = max_yaw_rate * sin(omega_s * t(i));
                if i > 1, yaw(i) = yaw(i-1) + cur_rate * dt; end
                roll(i) = rad2deg(atan((v0 * deg2rad(cur_rate)) / g)) * 0.5;
                curr_x = curr_x + v0 * dt * cosd(yaw(i));
                curr_y = curr_y + v0 * dt * sind(yaw(i));
                x(i) = curr_x; y(i) = curr_y;
            end
            
        case 'LevelFlight'
            x = v0 .* t;
    end

    %% 3. 标准化输出
    Re = 6378137;
    lat = RefLat + rad2deg(x ./ Re);
    lon = RefLon + rad2deg(y ./ (Re .* cosd(RefLat)));
    
    outTable = table(t, lat, lon, z, yaw, pitch, roll, ...
        'VariableNames', {'Time_s', 'Lat_deg', 'Lon_deg', 'Alt_m', 'Yaw_deg', 'Pitch_deg', 'Roll_deg'});

    outDir = fullfile(fileparts(mfilename('fullpath')), '..', 'output');
    if ~exist(outDir, 'dir'), mkdir(outDir); end
    
    savePath = fullfile(outDir, sprintf('Trajectory_%s.csv', TrajType));
    writetable(outTable, savePath);
    fprintf('>> 导出成功: %s\n', savePath);

    %% 4. 绘图
    figure('Name', ['轨迹 3D 靶场 - ', TrajType], 'Color', 'w');
    plot3(lon, lat, z, 'k-', 'LineWidth', 1.5); grid on;
    xlabel('经度'); ylabel('纬度'); zlabel('高度(m)');
    title(['弹道预览: ', TrajType]);
end