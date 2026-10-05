# 正式申报书事实核对清单

这是一份核对清单，不是申报正文，不得代替参赛者亲自撰写的材料。
依据用户提供的十月报名表：Markdown、一页以内、不使用 AI 编写、至少三个完整使用场景。
参赛者已确认将亲自撰写；本轮未生成正式申报书或代填报名表。

| 必须包含的项目 | 可核对的工程事实或检查办法 |
|---|---|
| 项目名称 | MoonDBC；中文名称见 README |
| 项目简介 | 与已实现功能、用户目标和明确支持边界一致，由参赛者写正文 |
| 项目方向与通用性 | 原创 MoonBit DBC 数据库处理库与 CLI；不依赖实际 CAN 硬件 |
| 至少三个完整使用场景 | 由参赛者亲自写；逐个交代使用者、输入、处理过程、输出及用途，不能仅列三个行业名称 |
| 拟实现核心功能 | 已实现 parser/model/validation、Intel/Motorola、signed/scaling、enum/basic mux、writer/diff/inspect/layout/CLI |
| 原创、移植或参考类别 | 原创；没有从其他 DBC 库移植源码；公开格式参考及生态查重见 REFERENCES / ECOSYSTEM_REVIEW |
| 上游来源与许可证 | 如描述为移植，应补真实来源与范围；本项目是原创，Apache-2.0，官方 core/x 依赖和 cantools 测试 oracle 已声明 |
| GitHub 仓库与有效 commits | https://github.com/SongYZZZ/moon-dbc；公开 main，超过十个连续有效提交，无空提交或机械拆分 |

可引用的数据：三个后端各 203 tests 全过；1536 次附加固定 seed 断言；
41 个 cantools oracle 向量；15 个实际 CLI smoke；4660 有效 MoonBit 行，
其中 core/CLI 3001、tests 1511、bench 113、examples 35。
Mooncakes SongYZZZ/moon-dbc@0.1.0 已发布，独立 registry 下载和实际运行通过。

不能承诺的能力：完整 DBC 标准、extended/nested mux、浮点信号编码、
完整 CAN FD transport、硬件收发或保持原始排版的 writer。
提交前还需参赛者自行确认报名状态、赛事群和正式章程的其他要求。
