# MoonDBC：面向 CAN / CAN FD 的 DBC 数据库解析、校验与报文编解码工具库

参赛者：宋永振。GitHub：[SongYZZZ/moon-dbc](https://github.com/SongYZZZ/moon-dbc)。
项目为原创 MoonBit 开源工程，许可证 Apache-2.0，模块名 SongYZZZ/moon-dbc。

项目面向汽车电子、机器人和嵌入式开发中的 CAN 数据库处理需求，将 DBC 文本
转换为结构化 Message / Signal 模型，校验布局和网络引用，并在 raw 帧与物理量
之间双向转换。库不依赖真实硬件，不实现 CAN 驱动或上层诊断协议。

实现包含带位置与资源预算的解析器、Intel／Motorola 位操作、补码、比例偏移、
范围策略、枚举、基本 multiplex 和分支感知的重叠校验。属性与注释结构化保存。
确定性 writer、语义 diff、inspect、layout 和六个文件 CLI 命令提供工程实用性。

生态查重确认已有 curry3point/dbc-toolkit。MoonDBC 的独立价值集中在 basic mux、
属性与默认值、数据库／节点注释和完整文件 CLI；其源代码未复制或移植。

测试包含 203 个独立用例、1536 个固定种子 raw round-trip、人工 Motorola 位图、
41 个 cantools 交叉验证向量和真实 CLI smoke。CI 配置标准质量门与多后端检查。
文档提供支持表、位编号图、算法说明、实测 benchmark 和兼容性证据。

0.1.0 的边界为整数信号和基本 mux，不声称完整 DBC 或 CAN FD 传输层支持。
后续计划扩展 mux 树与范围、独立兼容样本和有边界的文件流读取。
代码规模目标为项目自定的 4000 行有效 MoonBit 代码；真实统计排除依赖、生成
接口、构建产物与 fixture，见 scripts/source-audit.ps1。
