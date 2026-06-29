function [AzPattern, ElPattern] = mapBodyAzElToPatternAngle(AzBody, ElBody, angleMap)
%MAPBODYAZELTOPATTERNANGLE 将几何模块输出的 Body Az/El 映射到方向图查询角
%
% 输入：
%   AzBody, ElBody:
%       几何模块输出的本体坐标系方向角，单位 deg。
%
%   angleMap:
%       angleMap.phiOffsetDeg
%       angleMap.thetaMode
%
% 输出：
%   AzPattern, ElPattern:
%       用于 getAntennaGain 查询方向图的角度。
%
% 弹载天线说明：
%       phi270 theta90 是头
%       phi90  theta90 是弹尾
%
%   若几何模块中：
%       AzBody = 0   表示弹头方向
%       AzBody = 180 表示弹尾方向
%
%   则应该：
%       AzPattern = AzBody + 270
%
%   这样：
%       AzBody = 0   -> Phi = 270，弹头
%       AzBody = 180 -> Phi = 90，弹尾

if nargin < 3 || isempty(angleMap)
    angleMap = struct();
end

if ~isfield(angleMap, 'phiOffsetDeg')
    angleMap.phiOffsetDeg = 0;
end

if ~isfield(angleMap, 'thetaMode')
    angleMap.thetaMode = 'identity';
end

AzBody = double(AzBody);
ElBody = double(ElBody);

AzPattern = mod(AzBody + angleMap.phiOffsetDeg, 360);

switch lower(string(angleMap.thetaMode))

    case "identity"
        % 直接使用 ElBody
        ElPattern = ElBody;

    case "zenith0_horizon90"
        % 几何 ElBody:
        %   +90 = 天顶
        %   0   = 水平
        %
        % 方向图 Theta:
        %   0  = 天顶
        %   90 = 水平
        ElPattern = 90 - ElBody;

    case "horizon90_zenith0"
        ElPattern = 90 - ElBody;

    case "neg_el"
        ElPattern = -ElBody;

    otherwise
        error('未知 thetaMode: %s', angleMap.thetaMode);
end

end