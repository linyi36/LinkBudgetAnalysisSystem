function [LinkResult, SimDiag] = linkSimOneScenario(TxNode, RxNode, AntTx, AntRx, GeoCfg, RfCfg, AntCfg, AlgoCfg)
% linkSimOneScenario
% 单场景链路仿真核心入口。

% 1. 轨迹预处理
[TxState, RxState, PreDiag] = linkPreprocessTrack(TxNode, RxNode, GeoCfg);

% 2. 计算几何几何序列
[GeoSeries, GeoDiag] = linkCalcGeometrySeries(TxState, RxState, GeoCfg);

% 3. 查询天线增益 (这里返回了包含新字段的 AntSeries)
[AntSeries, AntDiag] = linkCalcAntennaGainSeries(GeoSeries, AntTx, AntRx, AntCfg);

% 4. 计算链路预算
[BudgetSeries, BudgetDiag] = linkCalcBudgetSeries(GeoSeries, AntSeries, RfCfg, AlgoCfg);

% 5. 构造结果结构体
LinkResult = struct();
LinkResult.t = GeoSeries.t;
LinkResult.TxState = TxState;
LinkResult.RxState = RxState;
LinkResult.GeoSeries = GeoSeries;
LinkResult.AntSeries = AntSeries; % 保留原有的嵌套结构
LinkResult.BudgetSeries = BudgetSeries;
LinkResult.AntTx = AntTx;
LinkResult.AntRx = AntRx;

% --- 【修复关键点】：将 AntSeries 中的关键字段展平到 LinkResult 顶层 ---
% 这样 main_link_top.m 就可以直接通过 LinkResult.Az_query_tx 访问，不会报错了
LinkResult.Az_query_tx = AntSeries.Az_query_tx;
LinkResult.El_query_tx = AntSeries.El_query_tx;
LinkResult.Az_query_rx = AntSeries.Az_query_rx;
LinkResult.El_query_rx = AntSeries.El_query_rx;
LinkResult.Gt = AntSeries.Gt;
LinkResult.Gr = AntSeries.Gr;

% 6. 构造诊断信息
SimDiag = struct();
SimDiag.message = '单场景链路仿真完成。';
SimDiag.PreDiag = PreDiag;
SimDiag.GeoDiag = GeoDiag;
SimDiag.AntDiag = AntDiag;
SimDiag.BudgetDiag = BudgetDiag;

end