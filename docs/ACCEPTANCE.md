# moonmeter 验收自查矩阵（350 元完成支持）

本文对照《2026 MoonBit 国产基础软件开源大赛章程》阶段三"项目验收"的九条要求，
以及 8 月黑客松活动说明第六节的验收要求，逐条给出本地可复现的证据。
核查日期：**2026-11-26**。状态分为 `已满足`、`待发布`；结论只陈述可验证事实。

## 一、九条硬性要求逐条自查

| # | 官方验收要求 | 状态 | 本地证据 |
|---|---|---|---|
| 1 | 以 MoonBit 为主要实现语言 | 已满足 | 全部源码为 `.mbt`；实现 1841 行 + 测试 793 行（见下文统计命令），无其他语言实现文件 |
| 2 | 仓库公开可访问、提交记录清晰 | 已满足 | `origin = https://github.com/Krinph/moonmeter.git`；默认分支 `main`；21 个有效 commit，无空提交/重复提交 |
| 3 | README 说明目标、安装、使用、示例并可复现 | 已满足 | 根目录 `README.md`：目标、三个使用场景、`moon add` 安装、CLI/Library 用法、`moon run cmd/roundtrip` 预期输出 |
| 4 | 使用 CI 且覆盖检查、构建、测试流程 | 已满足 | `.github/workflows/check.yml`：Ubuntu/macOS/Windows 三平台，`moon check --target all --deny-warn`、`moon build --target all`、`moon test --target all`，另含 fmt/info 接口漂移检查与 CLI 冒烟 |
| 5 | 至少一个可运行示例 | 已满足 | `cmd/roundtrip`：构造请求 → 模拟电表 → 解码 → 格式化 → 校验，输出 `1234.56 kWh`；`moon run cmd/roundtrip` |
| 6 | 完整测试覆盖核心功能 | 已满足 | 61 项测试，12 功能码与多帧会话逐字节黄金用例；四后端（wasm/wasm-gc/js/native）全通过 |
| 7 | 发布到 mooncakes.io | **待发布** | `moon.mod` 元数据完整（见第二节），但 `moon publish --dry-run` 提示需先 `moon login`；须由账号持有人执行发布 |
| 8 | 采用 OSI 认可的开源许可证 | 已满足 | 根目录 `LICENSE`，Apache-2.0（OSI 认可）；原创实现，未复制第三方源代码，见申报书"原创与参考说明" |
| 9 | 完成度覆盖申报书核心承诺 | 已满足 | 申报书承诺的 12 功能码、三种应答控制码、多帧序号、DI 目录、模拟器、错误解码、一致性校验器、CLI、示例均已实现并测试；见 `docs/PROJECT_PROPOSAL.md` |

**结论**：九条中八条已满足并可本地复现；第 7 条 mooncakes.io 发布需账号持有人登录后执行，
是提交验收前的唯一待办项。

## 二、mooncakes.io 发布前置检查（均已就绪）

`moon.mod` 已具备发布所需元数据：

- `name = "Krinph/moonmeter"`：命名空间 `Krinph` 与 GitHub 账号一致；
- `version = "0.3.1"`，与 CLI `--version`、README、CHANGELOG、申报书一致；
- `readme = "README.mbt.md"`、`repository`、`license = "Apache-2.0"`、`keywords`、`description` 齐全；
- `preferred_target = "native"`；公开接口见 `pkg.generated.mbti`，已跟踪且与 `moon info` 一致。

发布步骤（须在持有 `Krinph` mooncakes 账号的机器上执行）：

```bash
cd moonmeter
export PATH=/c/Users/14870/.moon/bin:$PATH   # Windows/Git Bash；其他系统按实际安装路径
moon login                                  # 打开浏览器完成账号授权
moon publish --dry-run                      # 确认无报错
moon publish                                # 正式发布 0.3.1
```

发布成功后可用 `moon add Krinph/moonmeter` 拉取，或访问
`https://mooncakes.io/docs/Krinph/moonmeter` 确认包文档可见。

## 三、工程加分项（优秀项目评选参考项，非硬性）

- 四后端严格检查：`moon check --target all --deny-warn`、`moon test --target all` 全通过；
- 格式与接口漂移：`moon fmt --check`、`moon info` 无 diff；
- 标准符合性文档：`docs/STANDARD_CONFORMANCE.md` 含时效性核查、单帧与会话级逐字节案例；
- 规模：章程参考 4~10k 行但明确"不是强制验收标准"，本项目实现 + 测试共约 2634 行，
  功能边界完整、无空壳或占位代码，符合"真实可用、边界清晰、可维护"的评审取向。

## 四、一键复现命令

```bash
cd moonmeter
export PATH=/c/Users/14870/.moon/bin:$PATH
moon check --target all --deny-warn   # 检查
moon build --target all               # 构建
moon test --target all                # 61 项测试 × 4 后端
moon fmt --check                      # 格式
moon info                             # 公开接口（应与 pkg.generated.mbti 一致）
moon run cmd/roundtrip                # 可运行示例 -> 1234.56 kWh
# MoonBit 有效代码行数统计（不含 _build 与测试）
find . -name '*.mbt' ! -path './_build/*' ! -name '*_test.mbt' ! -name '*_wbtest.mbt' -print0 \
  | xargs -0 cat | wc -l
```

## 五、依据来源

- 《2026 MoonBit 国产基础软件生态开源大赛章程》（本地 `osc2026-guide/references/`，更新时间 2026-05-11）：
  阶段三验收九条要求、启动/完成支持 150/350 元、规模参考说明。
- 《2026 MoonBit 国产基础软件生态开源大赛-8月黑客松活动说明》（本地同上）：第六节验收要求、
  11 节奖励说明；规则与主线赛事基本一致。
- 官方赛事页 `https://moonbitlang.github.io/OSC2026/`：验收项目需 MoonBit 主语言、仓库公开、
  README、可运行示例、CI、测试与 mooncakes.io 发布。
- 补充 FAQ `osc2026-guide/references/supplemental-knowledge.md`：CI workflow 参考模板、
  仓库提交与开源合规说明。

> 注：赛事分支（主赛 / 8 月及后续黑客松）在赛程与评选范围上有差异，但验收硬性要求一致；
> 本矩阵按二者共同要求自查。若报名通道另有专门通知，以赛事组通知为准。
