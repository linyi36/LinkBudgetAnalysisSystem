function KeyDirTable = BuildKeyDirectionGainTable(Pattern)
% /*!
% * @brief 生成常用关键方向增益表。
% * @details 对弹载方向图输出弹头、弹尾、侧面、Z 轴方向；对地面方向图输出天顶和水平边缘。
% * @param[in] Pattern, struct, 方向图结构体。
% * @param[out] KeyDirTable, table, 关键方向增益表。
% */

ThetaMin = min(Pattern.ThetaUnique);
ThetaMax = max(Pattern.ThetaUnique);

DirectionName = {};
PhiDeg = [];
ThetaDeg = [];
GainDb = [];

if ThetaMin <= 0 && ThetaMax >= 180
    DirectionName = {'head'; 'tail'; 'side0'; 'side180'; 'top'};
    PhiDeg = [270; 90; 0; 180; 0];
    ThetaDeg = [90; 90; 90; 90; 0];
else
    DirectionName = {'top'; 'horizonPositive'; 'horizonNegative'; 'phi0Theta0'};
    PhiDeg = [0; 0; 0; 0];
    ThetaDeg = [0; 90; -90; 0];
end

for Idx = 1:numel(PhiDeg)
    GainDb(Idx, 1) = QueryPatternGain(Pattern, PhiDeg(Idx), ThetaDeg(Idx)); %#ok<AGROW>
end

KeyDirTable = table(DirectionName, PhiDeg, ThetaDeg, GainDb, ...
    'VariableNames', {'DirectionName', 'PhiDeg', 'ThetaDeg', 'GainDb'});
end
