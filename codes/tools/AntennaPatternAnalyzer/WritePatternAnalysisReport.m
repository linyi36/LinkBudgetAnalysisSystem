function WritePatternAnalysisReport(ReportPath, Pattern, Cfg, RegionStats, KeyDirTable, CutResult)
% /*!
% * @brief 将方向图分析结果写入 TXT 简要报告。
% * @param[in] ReportPath, char/string, 报告保存路径。
% * @param[in] Pattern, struct, 方向图结构体。
% * @param[in] Cfg, struct, 主脚本配置。
% * @param[in] RegionStats, struct, 区域统计结果。
% * @param[in] KeyDirTable, table, 关键方向增益表。
% * @param[in] CutResult, struct, 切面输出结果。
% */

ParentDir = fileparts(ReportPath);
if ~exist(ParentDir, 'dir')
    mkdir(ParentDir);
end

FileId = fopen(ReportPath, 'w');
if FileId < 0
    error('WritePatternAnalysisReport:OpenFailed', '无法写入报告：%s', ReportPath);
end

fprintf(FileId, 'Antenna Pattern Analyzer Report\n');
fprintf(FileId, '================================\n\n');
fprintf(FileId, 'Input file      : %s\n', Pattern.FilePath);
fprintf(FileId, 'Selected freq   : %.6g GHz\n', Pattern.SelectedFreqGHz);
fprintf(FileId, 'Phi range       : %.3f ~ %.3f deg\n', Pattern.PhiRangeDeg(1), Pattern.PhiRangeDeg(2));
fprintf(FileId, 'Theta range     : %.3f ~ %.3f deg\n', Pattern.ThetaRangeDeg(1), Pattern.ThetaRangeDeg(2));
fprintf(FileId, 'Gain range      : %.3f ~ %.3f dBi\n\n', Pattern.GainRangeDb(1), Pattern.GainRangeDb(2));

fprintf(FileId, 'Region Statistics\n');
fprintf(FileId, '-----------------\n');
fprintf(FileId, 'Region name     : %s\n', RegionStats.RegionName);
fprintf(FileId, 'Phi range       : %.3f ~ %.3f deg\n', RegionStats.PhiMinDeg, RegionStats.PhiMaxDeg);
fprintf(FileId, 'Theta range     : %.3f ~ %.3f deg\n', RegionStats.ThetaMinDeg, RegionStats.ThetaMaxDeg);
fprintf(FileId, 'Threshold       : %.3f dBi\n', RegionStats.ThresholdDb);
fprintf(FileId, 'Gain min        : %.3f dBi\n', RegionStats.GainMinDb);
fprintf(FileId, 'Gain mean       : %.3f dBi\n', RegionStats.GainMeanDb);
fprintf(FileId, 'Gain max        : %.3f dBi\n', RegionStats.GainMaxDb);
fprintf(FileId, 'Gain median     : %.3f dBi\n', RegionStats.GainMedianDb);
fprintf(FileId, 'Gain std        : %.3f dB\n', RegionStats.GainStdDb);
fprintf(FileId, 'Gain > threshold: %.2f %%\n', RegionStats.PercentGreaterThanThreshold);
fprintf(FileId, 'Pass flag       : %d\n\n', RegionStats.PassFlag);

fprintf(FileId, 'Key Direction Gain\n');
fprintf(FileId, '------------------\n');
for Idx = 1:height(KeyDirTable)
    fprintf(FileId, '%-18s Phi=%8.3f deg, Theta=%8.3f deg, Gain=%8.3f dBi\n', ...
        KeyDirTable.DirectionName{Idx}, KeyDirTable.PhiDeg(Idx), KeyDirTable.ThetaDeg(Idx), KeyDirTable.GainDb(Idx));
end
fprintf(FileId, '\n');

fprintf(FileId, 'Output Files\n');
fprintf(FileId, '------------\n');
fprintf(FileId, 'Fixed theta cut PNG : %s\n', CutResult.ThetaCutPng);
fprintf(FileId, 'Fixed phi cut PNG   : %s\n', CutResult.PhiCutPng);
fprintf(FileId, 'Cut data CSV        : %s\n', CutResult.CutCsv);

fclose(FileId);
end
