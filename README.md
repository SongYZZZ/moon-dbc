# MoonDBC

**面向 CAN / CAN FD 的 DBC 数据库解析、校验与报文编解码工具库**

宋永振（SongYZZZ）的原创 MoonBit 开源项目。仓库固定为
[SongYZZZ/moon-dbc](https://github.com/SongYZZZ/moon-dbc)，Apache-2.0。
[English](README_EN.md)

以下输出来自实际运行的原生 CLI：

```text
> .\dist\moon-dbc.exe inspect tests/fixtures/basic.dbc
DBC database
Version: 1.0
Nodes: 2
Messages: 1
Signals: 2
Standard CAN messages: 1
Extended CAN messages: 0
Classic-sized messages: 1
CAN FD-sized messages: 0
Multiplexed messages: 0
Value descriptions: 2
Diagnostics: 0 errors, 0 warnings

> .\dist\moon-dbc.exe decode tests/fixtures/basic.dbc 0x123 E02E030000000000
Message: EngineData (DBC ID 291)
EngineSpeed: raw=12000 value=1500 rpm
Gear: raw=3 value=3  (Drive)

> .\dist\moon-dbc.exe diff tests/fixtures/basic.dbc tests/fixtures/basic.dbc
Semantic changes: 0
```

## 用途

DBC 描述帧标识符、信号位布局、比例、偏移、单位和枚举。MoonDBC 将这些文本定义转换为结构化模型，供汽车电子、机器人与嵌入式测试程序解释采集的帧、构造测试向量、检查布局冲突或比较数据库修订。

它处理数据库和内存中的帧。CAN 驱动负责实际总线收发；USB-CAN、SocketCAN、硬件时序、BRS、CRC、ISO-TP、UDS 和 J1939 协议层不属于本库。

## 已实现能力

- Database、Node、Message、Signal、FrameId、CanFrame 和结构化 Diagnostic。
- 带行列位置的词法与语法解析、输入限制、strict / permissive 模式。
- Intel 与 DBC Motorola 位编号，1～64 位 signed / unsigned 精确 raw 值。
- factor / offset、明确的舍入策略和 Reject / Ignore / Warn / Clamp 范围策略。
- `VAL_` 枚举及 label 编码；基本 `M`、`mN` 多路复用。
- mux 分支感知的重叠检查、引用、重复定义、属性类型、范围、默认值校验。
- 标准／扩展 CAN ID，保留原始 DBC ID；0～64 字节载荷。
- 确定性 DBC writer、语义 diff、统计、真实 bit layout。
- 文件 CLI：inspect、validate、decode、encode、diff、layout；附加 normalize。
- 缓存并快照布局的 CompiledMessage，适合连续处理多帧。

## 格式范围

| 结构 | 0.1.0 状态 |
|---|---|
| VERSION、BU_、BO_、SG_ | 支持文档化的核心语法 |
| NS_ | 支持命名空间声明；以 BS_ 结束 |
| BS_ | 仅空段；不支持位时序字段 |
| CM_ | database / node / message / signal |
| VAL_ | 支持；raw 标签键为 Int64 |
| BA_DEF_、BA_DEF_DEF_、BA_ | INT、HEX、FLOAT、STRING、ENUM；四种 scope |
| VAL_TABLE_、BO_TX_BU_、SIG_GROUP_、EV_ | 不作结构化解释；strict 拒绝，permissive 保留文本并警告 |
| SIG_VALTYPE_、SG_MUL_VAL_、SIG_TYPE_REF_ | 编解码关键扩展，两个模式均拒绝 |

DBC 存在厂商扩展和历史实现差异。本库不声称完整 DBC 标准兼容。详见
[FORMAT_SUPPORT](docs/FORMAT_SUPPORT.md)、[PARSER_MODES](docs/PARSER_MODES.md)。

## 安装与构建

使用官方 MoonBit 工具链。本次验证版本为 moonc v0.10.9（2026-08-19）。
项目配置由当前 `moon new` 生成，使用 `moon.mod` 和 `moon.pkg`。
从仓库根目录运行：

```powershell
moon version --all
moon update
moon check
moon test
moon fmt --check
moon build
moon info
pwsh -NoProfile -File scripts/build-cli.ps1
```

构建脚本生成 `dist/moon-dbc.exe`。核心库不依赖硬件，也不依赖 Python。
官方 `moonbitlang/x` 0.5.1 仅用于 CLI 的文件读写与进程退出。
原生 stderr 的少量 C 代码只承担进程输出，DBC 核心全部使用 MoonBit。

Mooncakes 模块名：`SongYZZZ/moon-dbc`，版本 0.1.0。模块名与元数据已经
通过真实 `moon package` 验证；实际发布状态见 [Completion Report](docs/COMPLETION_REPORT.md)。

## Library API

在 `moon.pkg` 中 import `SongYZZZ/moon-dbc` 并取别名 `dbc`。
完整可执行代码位于 [examples/basic](examples/basic/main.mbt)：

```moonbit
let db = @dbc.parse_dbc(source)
let message = db.message_by_name("Engine").unwrap()
let encoded = @dbc.encode_message(message, [
  { name: "Speed", value: Physical(1500) },
])
let decoded = @dbc.decode_frame(db, encoded.frame)
```

公共 API 使用 `raise DbcError`，调用者应捕获 `Failure(Diagnostic)`。
`unwrap` 仅用于已知存在的示例对象；未知查询返回 Option。
查询还包括 message_by_id、node_by_name、signal_by_name 和 find_signals。
连续处理时先 `compile_message(message)`，再调用 `.encode` / `.decode`。
导出接口见 [pkg.generated.mbti](pkg.generated.mbti)，设计见 [DESIGN](docs/DESIGN.md)。

```powershell
moon run examples/basic
moon run examples/multiplex
```

## CLI

```powershell
.\dist\moon-dbc.exe inspect tests/fixtures/basic.dbc --message 0x123
.\dist\moon-dbc.exe validate tests/fixtures/basic.dbc
.\dist\moon-dbc.exe decode tests/fixtures/basic.dbc 0x123 E02E030000000000
.\dist\moon-dbc.exe decode tests/fixtures/motorola.dbc 292 0540FFF000000000 --json
.\dist\moon-dbc.exe encode tests/fixtures/basic.dbc 0x123 EngineSpeed=1500 Gear=3
.\dist\moon-dbc.exe encode tests/fixtures/basic.dbc 0x123 --raw EngineSpeed=12000 Gear=3
.\dist\moon-dbc.exe layout tests/fixtures/multiplex.dbc 293
.\dist\moon-dbc.exe diff tests/fixtures/basic.dbc tests/fixtures/basic.dbc
.\dist\moon-dbc.exe normalize tests/fixtures/attributes.dbc
```

枚举 label 输入写成 `Gear=label:Drive`。所有文件命令接受 `--permissive`。
CLI ID 是原始 DBC ID，可用十进制或 `0x`；扩展帧必须包含 bit 31 标志。
解码 JSON 中 raw 是十进制字符串，避免 JavaScript 消费者丢失 64 位整数精度。
exit code：成功 0；validate 有错误或 diff 有差异 1；参数、IO、parse、codec 错误 2。

也可以直接从根目录运行：

```powershell
moon run cmd/main -- inspect tests/fixtures/basic.dbc
moon run --target native cmd/main -- decode tests/fixtures/basic.dbc 0x123 E02E030000000000
moon run --target js cmd/main -- decode tests/fixtures/basic.dbc 0x123 E02E030000000000 --json
```

## 编解码约定

Intel 的 start bit 指向 LSB；Motorola 的 start bit 指向 MSB，跨字节使用锯齿编号。
见带人工位图的 [BIT_NUMBERING](docs/BIT_NUMBERING.md)。

`physical = raw * factor + offset`。物理量编码采用最近整数、半值远离零；
默认 Reject 范围越界，绝不自动 Clamp。量化后也检查范围。
`[0|0]` 表示声明范围仅为零，本项目不把它自动解释为未知范围。
可显式选择 Ignore，或用精确 raw API。Warn 在整帧编码结果中记录 warning。
超过 Double 精确整数范围的物理输入被拒绝，完整 64 位值用 RawValue 输入。

mux 根据 selector 的 **raw 值**选择分支。无已知分支时解码返回 selector 和
always-active 信号，并产生 warning；编码拒绝 inactive、unknown、重复和缺失的 active 输入。
帧 payload 长度必须精确等于 Message.length；不截断、不补齐。

0～64 字节是数据库载荷范围。大于 8 字节只称为 CAN FD-sized，
不声称实现 CAN FD DLC 映射、BRS、CRC 或收发总线的传输语义。

## 诊断与测试

实际错误示例：`error [signal.overlap] line 5:2 Collision.B: overlap with A at bit 4`。
解析错误与严重布局错误会抛出；validate_database 收集可检查的语义问题。

187 个非重复 MoonBit 测试已通过默认 wasm-gc；native、JS 同样执行验证。
固定种子测试另外执行 1536 个 raw round-trip，不把这些循环伪装成独立 test 数。
37 个 cantools 44.1.0 交叉验证向量通过；13 个实际 CLI smoke 用例通过。

```powershell
moon check --deny-warn
moon test --deny-warn
moon test --target native --deny-warn
moon test --target js --deny-warn
pwsh -NoProfile -File scripts/smoke.ps1
pwsh -NoProfile -File scripts/source-audit.ps1
moon bench --target native --release
moon package
```

[TESTING](docs/TESTING.md) 说明验证方法，[COMPATIBILITY](docs/COMPATIBILITY.md)
提供真实 oracle 记录，[BENCHMARKS](docs/BENCHMARKS.md) 给出实测环境和数值。
未声称 coverage 百分比。GitHub Actions 配置在 `.github/workflows/ci.yml`；
远程 CI 是否通过，以 GitHub 实际 run 状态为准。

## 工程与维护

根包按 model、lexer / parser、validation、raw / frame codec、writer、analysis、diff
和 pure CLI command 分文件；`cmd/main` 只负责参数、文件、打印和退出。
`tests/fixtures` 全部为原创最小数据库，许可证与仓库一致；`examples` 可运行。
源码规模通过审计脚本统计，排除生成接口、构建产物、依赖缓存和 fixture。

已知限制：extended multiplex、浮点信号、环境变量语义、信号组、多发送节点、
值表尚未结构化支持；writer 是语义序列化，不保持原始排版。
permissive 保存的扩展不进入 codec；多行未知扩展按文本行保存，不能推断其语义。
CLI 官方 IO 包先读取完整文件；解析预算限制进入模型的内容，调用者仍应限制
文件来源与读取大小。Wasm CLI 的错误输出走 stdout；native / JS 走 stderr。

Roadmap：0.2 扩展 mux 的树与范围；更多独立 oracle / 厂商兼容样本；
有边界的流式文件读取；可选 transport DLC 工具。
贡献指南见 [CONTRIBUTING](CONTRIBUTING.md)，漏洞反馈见 [SECURITY](SECURITY.md)。
参考与原创性声明见 [REFERENCES](docs/REFERENCES.md)，生态查重见
[ECOSYSTEM_REVIEW](docs/ECOSYSTEM_REVIEW.md)。[License](LICENSE)：Apache-2.0。
