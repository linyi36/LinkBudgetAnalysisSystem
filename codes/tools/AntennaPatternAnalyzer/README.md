# AntennaPatternAnalyzer

## 功能说明

本工具用于读取天线方向图 CSV，并进行方向图可视化、切面分析、ROI 区域统计和交互式查询。

本版本保留老师原版小工具中的四类方向图：

1. Fig.100：二维伪彩色热力图 `pcolor`
2. Fig.200：二维等高线图 `contourf`，并叠加实线等高线、ROI 边框和极值点
3. Fig.300：三维极坐标方向图，形状使用真实线性幅度，颜色使用真实 dBi
4. Fig.400：`patternCustom` 三维方向图，若当前 MATLAB 没有 Antenna Toolbox，则自动跳过

同时新增：

1. 固定多个 Theta 扫描 Phi，并画到同一张图
2. 固定多个 Phi 扫描 Theta，并画到同一张图
3. 指定 ROI 区域统计 min / mean / max / median / std
4. 统计 ROI 内 Gain 大于指定阈值的比例
5. 输出关键方向增益表
6. 在交互界面中支持 Phi/Theta 滑块和手动输入查询
7. 在交互界面中增加等高线图 / 伪彩色图切换复选框
8. 在交互界面右下角增加 ROI 区域分析框

## 目录结构

```text
AntennaPatternAnalyzer/
├── input/                         # 输入方向图 CSV
├── output/                        # 输出图像、CSV、TXT 报告
├── mainPlotGain.m                 # 主入口脚本
├── ReadAntennaPatternCsv.m        # 读取方向图 CSV
├── PlotPatternOverviewFigures.m   # 绘制 Fig.100/200/300/400
├── PlotPatternCuts.m              # 绘制一维切面图
├── AnalyzeGainRegion.m            # ROI 区域统计
├── QueryPatternGain.m             # 指定 Phi/Theta 查询 Gain
├── BuildKeyDirectionGainTable.m   # 关键方向增益表
├── OpenPatternSlider.m            # 滑块、手动输入、ROI UI 界面
└── WritePatternAnalysisReport.m   # 输出 TXT 报告
```

## 运行方式

```matlab
clear; clc; close all;
cd('工程目录/codes/tools/AntennaPatternAnalyzer')
mainPlotGain
```

## 主要配置

在 `mainPlotGain.m` 中修改：

```matlab
Cfg.PatternFileName = '314B_Air_RealizedGainPlot.csv';
Cfg.PhiRangeDeg     = [75, 105];
Cfg.ThetaRangeDeg   = [75, 105];
Cfg.GainThresholdDb = -5;
Cfg.FixedThetaListDeg = [75, 90, 105];
Cfg.FixedPhiListDeg   = [90, 270];
Cfg.FlagOpenSlider = true;
```

## 输出结果

输出目录为：

```text
output/方向图文件名/
```

主要输出包括：

- `*_Fig100_PseudoColorHeatmap.png`
- `*_Fig200_Contour_ROI.png`
- `*_Fig300_3D_SphericalPattern.png`
- `*_Fig400_PatternCustom.png`，需要 Antenna Toolbox
- `*_FixedThetaScanPhi.png`
- `*_FixedPhiScanTheta.png`
- `*_RegionStats.csv`
- `*_KeyDirectionGain.csv`
- `*_CutData.csv`
- `*_AnalysisReport.txt`
