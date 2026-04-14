# 第一批省级面板数据（2016-2024）数据字典

数据文件：`supply_chain_resilience/data/panels/first_batch_panel_2016_2024.csv`

行粒度：每行 = 省份（region）x 年份（year）。

字段说明：
- `region_code`：省级行政区划代码（国家数据平台口径）。
- `region_name`：省级行政区名称。
- `year`：年份。
- `A060101_value`：经营单位所在地进出口总额（来源代码见 `A060101_value__source_code`）。
- `A060201_value`：境内目的地和货源地进出口总额（来源代码见 `A060201_value__source_code`）。
- `A0G0E01_value`：快递量（来源代码见 `A0G0E01_value__source_code`）。
- `*_value__source_code`：该列实际从“国家数据 easyquery”返回的指标代码（用于追溯口径）。

原始抓取长表：
- `supply_chain_resilience/data/public_indicators/A060101.csv`
- `supply_chain_resilience/data/public_indicators/A060201.csv`
- `supply_chain_resilience/data/public_indicators/A0G0E.csv`
