# MoonDBC 终审自查报告

自查日期：2026-10-05（Asia/Shanghai）。仓库：SongYZZZ/moon-dbc。
使用技能：本机 `C:/Users/Lenovo/.codex/skills/osc2026-guide/SKILL.md` 的
Review Mode / Acceptance Review Checks，配合 chinese-output。

## 总体判断

工程验收检查通过；Mooncakes 正式发布及修复后远程 CI 的结果仍待最终核验。
自查不能替代赛事方的审核、验收或获奖决定。

规则范围分开处理：

- 用户十月方案第七十九节是本项目的硬性功能与规模验收清单。
- osc2026-guide 的通用终审标准作为加严自查，包括有效工程、测试、实际运行、
  已发布 Mooncakes、明确许可证、合理提交和实质完成；不套用八月报名表、日期、
  OSC2026 Gitlink 要求或八月复赛限制。
- [十月官方页面](https://moonbitlang.github.io/Hackathon2026/) 及其
  [公开页面源码](https://github.com/moonbitlang/Hackathon2026/blob/main/src/App.tsx)
  可见的要求为 MoonBit 为主、公开持续提交、README、可运行示例、必要测试、
  实质新增与来源说明。官网标注报名与验收截至 2026-10-31。
- 官网指向的[正式飞书章程](https://bxup9uklfcb.feishu.cn/wiki/Dx4Bwd6D1i3GfHkajQCcF7SznEd)
  在本次工具中无法读取，未将技能的八月章程当成十月正式章程。

## 硬性项目检查

| 项目 | 结果与证据 |
|---|---|
| 有效 MoonBit 工程 | moon.mod / moon.pkg；moonc v0.10.9+6e6c44045 |
| 仓库与贡献关系 | 公开 SongYZZZ/moon-dbc；API 核实 default branch 为 main；提交作者 SongYZZZ；申报者宋永振 |
| 许可证 | 根 LICENSE 是完整 Apache-2.0，元数据一致 |
| 原创性与生态价值 | 独立实现；ECOSYSTEM_REVIEW 说明已有 dbc-toolkit 和 basic mux、属性、文件 CLI 等差异，不声称首个 DBC 库 |
| DBC model / parser | 核心语法、元数据、位置诊断、strict/permissive、解析预算有真实源码与测试 |
| Frame codec | Intel/Motorola、signed、factor/offset、enum、basic mux、缓存布局和 0～64 字节载荷 |
| 工具功能 | validation、writer、semantic diff、inspect、layout 与七个文件 CLI 命令 |
| 测试 | wasm-gc/native/JS 各 203/203，0 failed；1536 次附加固定 seed 断言 |
| 独立 oracle | cantools 44.1.0，41/41；新增四个大整数 physical encode 精确对照 |
| 严格质量门 | moon check --deny-warn、moon test --deny-warn、moon fmt --check、moon build、moon info + moon fmt 已执行 |
| 实际运行 | 两个 MoonBit examples、native CLI 15/15 smoke、7/7 native benchmarks |
| 源码规模 | 4660 有效 MoonBit 行：core/CLI 3001、tests 1511、bench 113、examples 35；不含依赖/接口/build/fixture |
| 提交历史 | 开发基线 16 个连续功能提交，均为 2026-10-05；本次终审修复与发布证据会继续追加 |
| 文档与申报 | 中英文 README、BIT_NUMBERING、FORMAT_SUPPORT、REFERENCES、设计/测试/兼容性/基准；PROJECT_APPLICATION 约一页 Markdown |
| 仓库整洁 | git tracked files 未包含 credentials、_build、.oracle、.mooncakes、dist、临时验收目录；这些目录被忽略 |
| Mooncakes | 打包与解包 check 已通过；待正式上传成功及 registry 安装验证 |
| 远程 CI | 基线最终提交 7fb79b1 的 run 37300035094 成功；本次修复提交须再次跑 CI |

## 自查发现与修复

1. **大整数物理编码舍入错误。** `floor(abs(x)+0.5)` 在 2^52 以上可能改变本已
   精确的奇整数。先添加测试，实际得到 4 个失败；改为比较小数部分再决定进位。
   现在覆盖正负奇整数、2^53-1 和大值半整数。四个独立 cantools 向量也检查 physical encode。
2. **quoted token 与语法 token 混淆。** 对象关键字作为 CM_ 文本/STRING 值、
   属性名称等合法字符串需保留；带引号的正负号、类型、逗号、换行不能充当语法。
   修复 Parser cursor、属性定义和扩展保存，并添加相应正反例。
3. **发布进程误读旧凭据。** 用户终端 MOON_HOME 为 D:\Moonbit，但工具进程未
   继承用户级环境变量，误读 C:\Users\Lenovo\.moon 下的旧会话。显式指定
   MOON_HOME=D:\Moonbit 后 moon whoami 为 SongYZZZ；不用更改模块 owner 或用户凭据。

以上前两类修复新增 16 个独立测试。公开 API 接口文件没有非预期变化。
本次检查直接阅读 model、lexer、parser/cursor、bits、raw/frame codec、validation、
writer、diff、CLI 与 IO 边界；没有仅凭 README 判定实现完成。

## 需要进一步确认的问题

- 赛事报名表是否提交成功、资格审核状态、群昵称及入群状态，无法从仓库确定。
  本次未代填报名表、未发消息或声称已正式通过终审。
- 2026-10-05 之前的独立项目提交关系不能单凭当前仓库证明；不把八月的重复参赛
  条款套用到十月，也不声称已经核验赛事方全部报名记录。
- 正式飞书章程中超出官网可见要求的条款，需要赛事方材料才能核验。

## 边界与建议改进

CLI 读取完整文件后 parser 才限制输入，尚无流式 IO 上限；writer 不保持排版；
extended mux、浮点信号、非空 BS_、环境变量等未支持且已公开说明。
VAL_ 键使用 Int64，64 位 unsigned raw 仍支持完整范围。
没有宣称完整 DBC 标准、完整 CAN FD transport、覆盖率百分比或硬件收发。
这些明确边界未减少用户方案中 basic mux 与整数 codec 的承诺。

本机未检出 moonbitlang/skills；当前工具链高于技能建议的 0.10.7。
官方开发技能属于可选环境补充，不作为本项目终审阻塞项，也未擅自安装。

## 已检查的证据

源码与测试：根目录 .mbt 及 acceptance_regression_test.mbt。
外部 oracle：[COMPATIBILITY](COMPATIBILITY.md)、[interop-results.json](interop-results.json)。
基准：[BENCHMARKS](BENCHMARKS.md)、[benchmark-native.txt](benchmark-native.txt)。
汇总：[COMPLETION_REPORT](COMPLETION_REPORT.md)。
GitHub CI 与 Mooncakes 的最新结果会在正式上传、安装复验后同步到本报告。
