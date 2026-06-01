function Pattern = ReadAntennaPatternCsv(FilePath, TargetFreqGHz)
% /*!
% * @brief 读取天线方向图 CSV，并整理为 Phi/Theta/Gain 规则网格。
% * @details 自动识别 Phi、Theta、Gain 列；若存在 Freq 列，则选择最接近目标频率的频点。
% * @param[in] FilePath, char/string, CSV 文件路径。
% * @param[in] TargetFreqGHz, 1x1 double, 目标频率，单位 GHz；无频率列时可忽略。
% * @param[out] Pattern, struct, 包含原始列向量、规则网格和元信息。
% * @pre CSV 文件必须存在。
% * @bug Null
% * @warning Gain 列通过列名中包含 Gain 自动识别。
% * @author Lin Yi
% * @version 1.0
% * @date 2026.05.30
% */

if ~exist(FilePath, 'file')
    error('ReadAntennaPatternCsv:FileNotFound', '方向图文件不存在：%s', FilePath);
end

try
    DataTable = readtable(FilePath, 'VariableNamingRule', 'preserve');
catch
    DataTable = readtable(FilePath);
end

VarNames = string(DataTable.Properties.VariableNames);
NormNames = lower(regexprep(VarNames, '[\s_\[\]\(\)]', ''));

IdxPhi   = FindColumnIndex(NormNames, {'phi'});
IdxTheta = FindColumnIndex(NormNames, {'theta'});
IdxGain  = FindColumnIndex(NormNames, {'realizedgain', 'gain'});
IdxFreq  = FindColumnIndex(NormNames, {'freq'});

if isempty(IdxPhi) || isempty(IdxTheta) || isempty(IdxGain)
    error('ReadAntennaPatternCsv:InvalidHeader', ...
        'CSV 必须包含 Phi、Theta 和 Gain 相关字段。当前字段：%s', strjoin(VarNames, ', '));
end

if nargin < 2 || isempty(TargetFreqGHz)
    TargetFreqGHz = NaN;
end

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

Phi   = DataTable{:, IdxPhi};
Theta = DataTable{:, IdxTheta};
Gain  = DataTable{:, IdxGain};

Phi   = Phi(:);
Theta = Theta(:);
Gain  = Gain(:);

PhiUnique   = unique(Phi);
ThetaUnique = unique(Theta);
[PhiGrid, ThetaGrid] = meshgrid(PhiUnique, ThetaUnique);
GainGrid = nan(size(PhiGrid));

for IdxPoint = 1:numel(Gain)
    [~, IdxPhiGrid]   = min(abs(PhiUnique - Phi(IdxPoint)));
    [~, IdxThetaGrid] = min(abs(ThetaUnique - Theta(IdxPoint)));
    GainGrid(IdxThetaGrid, IdxPhiGrid) = Gain(IdxPoint);
end

if any(isnan(GainGrid(:)))
    GainGridInterp = griddata(Phi, Theta, Gain, PhiGrid, ThetaGrid, 'linear');
    FillMask = isnan(GainGrid) & ~isnan(GainGridInterp);
    GainGrid(FillMask) = GainGridInterp(FillMask);
end

if any(isnan(GainGrid(:)))
    GainNoNan = Gain(~isnan(Gain));
    GainGrid(isnan(GainGrid)) = min(GainNoNan);
end

Pattern = struct();
Pattern.FilePath        = char(FilePath);
[~, FileBaseName, FileExt] = fileparts(FilePath);
Pattern.FileName        = [FileBaseName, FileExt];
Pattern.FileBaseName    = FileBaseName;
Pattern.TargetFreqGHz   = TargetFreqGHz;
Pattern.SelectedFreqGHz = SelectedFreqGHz;
Pattern.Phi             = Phi;
Pattern.Theta           = Theta;
Pattern.Gain            = Gain;
Pattern.PhiUnique       = PhiUnique;
Pattern.ThetaUnique     = ThetaUnique;
Pattern.PhiGrid         = PhiGrid;
Pattern.ThetaGrid       = ThetaGrid;
Pattern.GainGrid        = GainGrid;
Pattern.PhiRangeDeg     = [min(Phi), max(Phi)];
Pattern.ThetaRangeDeg   = [min(Theta), max(Theta)];
Pattern.GainRangeDb     = [min(Gain), max(Gain)];
Pattern.ColumnNames     = VarNames;
end

function Idx = FindColumnIndex(NormNames, Keywords)
Idx = [];
for IdxKey = 1:numel(Keywords)
    Hit = find(contains(NormNames, lower(Keywords{IdxKey})), 1, 'first');
    if ~isempty(Hit)
        Idx = Hit;
        return;
    end
end
end
