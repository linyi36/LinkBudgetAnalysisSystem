# AntennaPatternAnalyzer

该工具用于读取 `input` 文件夹中的天线方向图 CSV，并输出方向图分析结果。

## 目录结构

```text
AntennaPatternAnalyzer/
├── input/                      # 输入方向图 CSV，可放多个方向图
├── output/                     # 输出 PNG、CSV、TXT 结果
├── mainPlotGain.m              # 主入口脚本
├── ReadAntennaPatternCsv.m     # 读取方向图
├── PlotPatternContour.m        # 二维等高线图
├── PlotPatternCuts.m           # 一维切面图，支持多个固定角度
├── AnalyzeGainRegion.m         # 指定区域统计
├── QueryPatternGain.m          # 指定 Phi/Theta 查询 Gain
└── OpenPatternSlider.m         # 可选滑块交互界面
```

## 运行方法

在 MATLAB 中运行：

```matlab
clear; clc; close all;
cd('工程根目录/codes/tools/AntennaPatternAnalyzer')
mainPlotGain
```

## 当前支持功能

1. 绘制 Phi/Theta/Gain 二维等高线图；
2. 固定 Theta 扫描 Phi，或固定 Phi 扫描 Theta；
3. 固定角度支持向量输入，多条切面会画到同一张图上；
4. 支持指定 Phi/Theta 查询 Gain；
5. 支持指定角度区域统计 min/mean/max/median/std，以及 Gain 大于指定阈值的比例；
6. 支持输出 PNG 图、CSV 统计结果和 TXT 简要报告；
7. 可选打开 Phi/Theta 滑块交互界面。

## 输入与输出

- 输入：`input/*.csv`
- 输出：`output/<方向图文件名>/`
