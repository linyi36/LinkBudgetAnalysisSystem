function AntCfg = loadConfigFromExcel(excelPath, AntCfg)
% 从 Excel 文件读取天线安装偏角，并覆盖到 AntCfg 结构体中

    if ~exist(excelPath, 'file')
        warning('未找到配置文件 %s，将使用系统默认配置。', excelPath);
        return;
    end

    % 读取 Excel (保持变量名不被篡改)
    Opts = detectImportOptions(excelPath);
    Opts.VariableNamingRule = 'preserve';
    T = readtable(excelPath, Opts);

    % 遍历表格，更新 Tx 配置
    AntCfg.tx.angleMap.MountYawDeg   = getParamValue(T, 'Tx_MountYawDeg', 0);
    AntCfg.tx.angleMap.MountPitchDeg = getParamValue(T, 'Tx_MountPitchDeg', 0);
    AntCfg.tx.angleMap.MountRollDeg  = getParamValue(T, 'Tx_MountRollDeg', 0);

    % 遍历表格，更新 Rx 配置
    AntCfg.rx.angleMap.MountYawDeg   = getParamValue(T, 'Rx_MountYawDeg', 0);
    AntCfg.rx.angleMap.MountPitchDeg = getParamValue(T, 'Rx_MountPitchDeg', 0);
    AntCfg.rx.angleMap.MountRollDeg  = getParamValue(T, 'Rx_MountRollDeg', 0);

    fprintf('成功从 %s 加载外部 Excel 天线配置。\n', excelPath);
end

% 本地辅助函数：根据参数名查找数值
function val = getParamValue(Table, paramName, defaultVal)
    % 假设 Excel 的第一列叫 ParamName，第二列叫 ParamValue
    idx = strcmpi(Table.ParamName, paramName);
    if any(idx)
        val = Table.ParamValue(idx);
        val = val(1); % 防御性编程：如果有重复的，取第一个
    else
        val = defaultVal;
    end
end