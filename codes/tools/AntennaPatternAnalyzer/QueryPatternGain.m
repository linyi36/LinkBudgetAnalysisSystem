function GainDb = QueryPatternGain(Pattern, PhiDeg, ThetaDeg)
% /*!
% * @brief 查询指定 Phi/Theta 方向上的 Gain。
% * @param[in] Pattern, struct, 方向图结构体。
% * @param[in] PhiDeg, scalar/vector, Phi 角度，单位 deg。
% * @param[in] ThetaDeg, scalar/vector, Theta 角度，单位 deg。
% * @param[out] GainDb, scalar/vector, 插值得到的 Gain，单位 dBi。
% */

PhiDeg = mod(PhiDeg, 360);
GainDb = interp2(Pattern.PhiGrid, Pattern.ThetaGrid, Pattern.GainGrid, PhiDeg, ThetaDeg, 'linear', NaN);

NanMask = isnan(GainDb);
if any(NanMask(:))
    GainNearest = interp2(Pattern.PhiGrid, Pattern.ThetaGrid, Pattern.GainGrid, PhiDeg, ThetaDeg, 'nearest', NaN);
    GainDb(NanMask) = GainNearest(NanMask);
end
end
