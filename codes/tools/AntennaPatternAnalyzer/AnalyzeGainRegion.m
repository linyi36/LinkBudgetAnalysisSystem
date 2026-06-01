function RegionStats = AnalyzeGainRegion(Pattern, PhiRangeDeg, ThetaRangeDeg, ThresholdDb, RegionName)
% /*!
% * @brief 对指定 Phi/Theta 区域内的 Gain 进行统计。
% * @param[in] Pattern, struct, 方向图结构体。
% * @param[in] PhiRangeDeg, 1x2 double, Phi 区域范围。
% * @param[in] ThetaRangeDeg, 1x2 double, Theta 区域范围。
% * @param[in] ThresholdDb, 1x1 double, 统计阈值。
% * @param[in] RegionName, char/string, 区域名称。
% * @param[out] RegionStats, struct, 区域统计结果。
% */

if nargin < 5 || isempty(RegionName)
    RegionName = 'Region';
end
if nargin < 4 || isempty(ThresholdDb)
    ThresholdDb = -Inf;
end

PhiMin = min(PhiRangeDeg);
PhiMax = max(PhiRangeDeg);
ThetaMin = min(ThetaRangeDeg);
ThetaMax = max(ThetaRangeDeg);

if PhiMin <= PhiMax
    PhiMask = Pattern.PhiGrid >= PhiMin & Pattern.PhiGrid <= PhiMax;
else
    PhiMask = Pattern.PhiGrid >= PhiMin | Pattern.PhiGrid <= PhiMax;
end
ThetaMask = Pattern.ThetaGrid >= ThetaMin & Pattern.ThetaGrid <= ThetaMax;
RegionMask = PhiMask & ThetaMask;

GainRegion = Pattern.GainGrid(RegionMask);
GainValid = GainRegion(~isnan(GainRegion));

if isempty(GainValid)
    error('AnalyzeGainRegion:EmptyRegion', '指定区域内没有有效 Gain 数据。');
end

RegionStats = struct();
RegionStats.RegionName = string(RegionName);
RegionStats.PhiMinDeg = PhiMin;
RegionStats.PhiMaxDeg = PhiMax;
RegionStats.ThetaMinDeg = ThetaMin;
RegionStats.ThetaMaxDeg = ThetaMax;
RegionStats.ThresholdDb = ThresholdDb;
RegionStats.NumValidPoints = numel(GainValid);
RegionStats.GainMinDb = min(GainValid);
RegionStats.GainMeanDb = mean(GainValid);
RegionStats.GainMaxDb = max(GainValid);
RegionStats.GainMedianDb = median(GainValid);
RegionStats.GainStdDb = std(GainValid);
RegionStats.PercentGreaterThanThreshold = 100 * mean(GainValid > ThresholdDb);
RegionStats.PercentLessOrEqualThreshold = 100 * mean(GainValid <= ThresholdDb);
RegionStats.PassFlag = RegionStats.PercentGreaterThanThreshold >= 100;

fprintf('\n========== Region Gain Statistics ==========%s', newline);
fprintf('Region       : %s\n', RegionStats.RegionName);
fprintf('Phi range    : %.2f ~ %.2f deg\n', PhiMin, PhiMax);
fprintf('Theta range  : %.2f ~ %.2f deg\n', ThetaMin, ThetaMax);
fprintf('Threshold    : %.3f dBi\n', ThresholdDb);
fprintf('Gain min/mean/max/median/std = %.3f / %.3f / %.3f / %.3f / %.3f dBi\n', ...
    RegionStats.GainMinDb, RegionStats.GainMeanDb, RegionStats.GainMaxDb, ...
    RegionStats.GainMedianDb, RegionStats.GainStdDb);
fprintf('Gain > threshold percent = %.2f %%\n', RegionStats.PercentGreaterThanThreshold);
fprintf('============================================%s', newline);
end
