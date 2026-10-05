# MoonDBC Completion Report

验收日期：2026-10-05。以下仅记录已执行的检查与实现边界。

## Repository

本地：`D:\Moonbit\projects\moon-dbc`。目标仓库：
[SongYZZZ/moon-dbc](https://github.com/SongYZZZ/moon-dbc)。Apache-2.0。
MoonDBC 为独立编写的 MoonBit 实现；未复制生态 DBC 项目代码。
GitHub API 已核实当前身份为 SongYZZZ；公开仓库已创建并推送，默认分支为 main。

## MoonBit Toolchain

本地实测：moon 0.1.20260819（fc2a4ee），moonc v0.10.9+6e6c44045
（2026-08-19），moonrun 0.1.20260819。Windows 11 Home 10.0.22621，
Intel Core i7-14650HX。CLI 使用官方 moonbitlang/x 0.5.1 文件 IO。

## Project Summary

DBC 数据模型、受预算约束的 parser、语义 validation、整数信号 codec、
basic multiplex、确定性 writer、semantic diff、inspect、layout 与真实文件 CLI。
库实现使用 MoonBit；native CLI 有 8 行 C stderr 桥接代码。
Python/cantools 仅用于独立测试，不参与库或 CLI 运行。

## Implemented DBC Syntax

`VERSION`、`NS_` 声明、空 `BS_`、`BU_`、`BO_`、`SG_`、四个对象作用域的
`CM_`、`VAL_`、`BA_DEF_`、`BA_DEF_DEF_`、`BA_`。属性包括 INT、HEX、FLOAT、
STRING、ENUM。支持引用后置的注释、属性和值描述以及转义字符串。
Strict 拒绝未知记录；permissive 保存非关键扩展文本并发出 warning。
浮点信号与扩展 mux 等会改变 codec 的关键扩展在两种模式中均拒绝。
具体矩阵见 [FORMAT_SUPPORT](FORMAT_SUPPORT.md)。

## Frame Codec

Intel：递增 LSB 位布局，包括非字节对齐。
Motorola：DBC sawtooth MSB 布局，跨字节时从 bit 0 跳至下一字节 bit 7。
Signed：1～64 位二进制补码，64 位 raw 不经过 Double。
Scaling：factor/offset、负 factor、最近整数舍入（半值远离零），
Reject/Clamp/Warn/Ignore 策略；超出精确整数区间时要求 raw API。
Multiplex：单个无符号 selector，以原始值选取分支；分支可共享位区间，
未知 selector 仅输出常驻信号与 selector 并给出 warning。
支持 0～64 字节数据库载荷；未实现 CAN FD DLC 或完整传输协议。

## Implemented Features

结构化诊断含 code、severity、行、列和 offset；解析输入、token、字符串、
message、signal 数量均有预算。校验 ID、名称、引用、范围、位宽、重叠、mux
与属性。CompiledMessage 缓存位位置与独立模型副本，可重复编解码。
Writer 保持模型语义和稳定顺序；diff 按 ID/name 比较有效字段。

## Public API

`parse_dbc`、`parse_dbc_with_options`、`validate_database`、`frame_id_from_dbc`、
`decode_signal_raw`、`encode_signal_raw`、`raw_to_physical`、`physical_to_raw`、
`compile_message`、`decode_frame`、`encode_message`、`write_dbc`、
`diff_database`、`inspect_database`、`message_layout`、`render_layout`。
完整签名以根目录实际 `moon info` 生成的 `pkg.generated.mbti` 为准。

## CLI

已构建 native release：`dist/moon-dbc.exe`。
命令：inspect、validate、decode、encode、diff、layout、normalize。
支持十进制/十六进制 DBC ID、decode JSON、raw encode、label encode、
inspect --message、permissive。退出码 0 成功，1 校验失败或存在 diff，2 命令错误。
实际 label encode `EngineSpeed=1500 Gear=label:Drive` 输出 `E02E030000000000`。
Native/JS 错误输出到 stderr；wasm 输出到 stdout，见已知限制。

## Tests

| Backend | Total | Passed | Failed |
|---|---:|---:|---:|
| wasm-gc | 203 | 203 | 0 |
| native | 203 | 203 | 0 |
| js | 203 | 203 | 0 |

另有固定 seed 的 1536 次布局/值断言，不计为独立测试 case。
已实际执行 moon info、moon fmt、moon fmt --check、moon check --deny-warn、
三个后端 moon test --deny-warn、moon build、native release build。
两个 MoonBit examples 均实际运行通过。

## Interoperability Tests

cantools 44.1.0，41/41 向量通过：raw 值、physical 值、活动信号与编码 bytes。
新增四个精确大整数向量，还对照了 physical encode 的输出 bytes。
包括 25 个 oracle 生成的 Motorola 非对齐和 signed 边界向量。
完整可复验记录见 [interop-results.json](interop-results.json)，
oracle 策略与覆盖边界见 [COMPATIBILITY](COMPATIBILITY.md)。

## Code Size

`scripts/source-audit.ps1` 的真实输出；有效行定义为非空且非纯注释行。
排除依赖、构建产物、生成接口、fixture 和非 MoonBit 文件。

| Category | Files | Physical lines | Effective lines |
|---|---:|---:|---:|
| Core MoonBit + CLI | 14 | 3367 | 3001 |
| Tests | 14 | 1915 | 1511 |
| Benchmarks | 1 | 128 | 113 |
| Examples | 2 | 37 | 35 |
| Total | 31 | 5447 | 4660 |

## CLI Smoke Tests

`scripts/smoke.ps1`：15/15 通过。包含全部七个命令、raw encode、JSON decode、
message inspect，以及 overlap（exit 1）、奇数 hex（exit 2）、缺失文件（exit 2）。
Label encode 与真实 factor 修订 diff 检查精确输出；有差异时确认为 exit 1。

## Benchmark

终审修复后重新执行 native release 的七项 benchmark。均值：小库解析 22.12 µs；
100 messages/800 signals 4.10 ms；1000/8000 为 48.92 ms；1000/10000 为
62.62 ms；缓存 decode 100k frames 121.55 ms；encode 100k 为 155.03 ms；
100 messages diff 2.06 ms。原始日志、标准差和测量范围见
[BENCHMARKS](BENCHMARKS.md)。未声称与其他工具的性能对比。

## CI

GitHub Actions 已在 Ubuntu **实际全部通过**：format/check/build、三个后端
各 187 个测试、两个 examples 与六项 CLI。
[成功 run 37299586605](https://github.com/SongYZZZ/moon-dbc/actions/runs/37299586605)
对应 cc91a141133ddcb7104d873deec073878f6f5f44，为上一轮 187 tests 的基线。
本次终审修复已在本地通过三个后端各 203 tests，推送后需要重新核验该提交的 CI。
CI 固定 compiler/core 为 0.10.9+6e6c44045，并初始化 registry。
首次 run 因 latest formatter 与本地格式版本不同失败；第二次因 clean runner
没有 registry 失败。这两项均已修复，未跳过格式或测试检查。

## Git

上一轮开发验收按功能连续创建 **16 个有意义的提交**，已推送到指定 owner。
最近的前置提交：cc91a14 初始化 registry；69e48ca 固定 compiler/core；
a591d9a 三后端验收与空模板清理；c504f7d 文档。最后的验收提交记录 remote CI
与实际 changed-factor/label CLI 检查。未 squash，未伪造历史。

## Mooncakes

Package status：**Ready to publish**（本节为 0.1.0 发布前的验收快照）。
`moon package --list` 已生成 `SongYZZZ-moon-dbc-0.1.0.zip`，check 通过；
`moon publish --dry-run` 实际执行了解包检查并与服务端交互，解包 check 通过。
此前服务端以 403 拒绝：模块 owner SongYZZZ 与令牌真实身份 hjn0123 不匹配。
本地凭据中的 username 不能作为发布身份依据。未发布到其他 namespace，
未更改 owner。包名已被本地正式打包工具接受。
用户已于 2026-10-05 通过 GitHub 重新执行 moon login。
已定位旧凭据误读原因：工具进程没有继承用户级 MOON_HOME，读取了
C:\Users\Lenovo\.moon 的 hjn0123 会话。显式 MOON_HOME=D:\Moonbit 后
moon whoami 显示 SongYZZZ。尚未获得本次服务端发布成功结果；
发布后的状态以 registry 和仓库最新报告为准。

## Known Limitations

CLI 官方 IO 先读取完整文件，parser 预算不等于流式文件读取上限。
Writer 是语义序列化，不保持原始排版；非关键未知扩展按行保存，不推断语义。
`[0|0]` 解释为字面零范围；VAL_ 键使用 Int64，完整 UInt64 raw 仍可编解码。
Wasm CLI 的错误输出走 stdout。互操作测试仅覆盖所列 fixture 与整数语义。

## Unsupported DBC Features

扩展/嵌套 multiplex、浮点信号编码、环境变量语义、信号组、多发送节点、
结构化值表、非空 BS_、CAN FD DLC 映射与 CAN transport。

## Remaining Work

执行本次 Mooncakes 0.1.0 发布并核验服务端结果。
GitHub 推送及远程 CI 已完成。后续版本可扩展 mux 和有边界的流式读取；
这些扩展未包含在当前兼容性声明中。
