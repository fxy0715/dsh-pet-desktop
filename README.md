# dsh-pet-desktop

<img src="./icon.svg" width="80" alt="DeepSeek 蓝色鲸鱼图标">

让一只 **DeepSeek 小蓝鲸** 在 Windows 桌面上陪伴你：透明置顶、轻轻游动，可以拖拽、点击互动，并记住上次手动放置的位置。

这是面向 **DeepSeek Harness（DSH）** 的桌面宠物插件。鲸鱼绘制在独立的 WPF 窗口中，可以离开 Harness 应用窗口活动；宿主插件负责管理它的启动与退出。

## 基本信息

| 项目 | 内容 |
| --- | --- |
| 包名 | `@local/dsh-pet-desktop` |
| 当前版本 | `1.0.0` |
| 插件形态 | Harness Host 端本地 Bundle + Windows 桌面子进程 |
| 支持平台 | Windows 桌面环境 |
| 技术栈 | JavaScript（ES Modules）、Windows PowerShell、WPF、C# |
| 图形 | 随包提供的 DeepSeek 鲸鱼矢量路径与蓝色渐变 |
| 发布方式 | 本地目录安装；`private: true`，不发布到 npm |

## 功能

- **桌面陪伴**：透明、无边框、置顶窗口，不占用任务栏按钮。
- **轻柔游动**：空闲时上下浮动并小范围漫游，游动方向改变时翻转朝向。
- **拖拽定位**：左键拖动鲸鱼，保存手动放置的位置；自动游动不会覆盖这个位置。
- **点击互动**：单击触发短暂的中文气泡和摇摆动画。
- **右键菜单**：暂停或恢复游走、回到右下角、退出。
- **屏幕边界约束**：拖拽与游动均限制在显示器工作区内，并处理显示器布局、分辨率和 DPI 变化。
- **生命周期管理**：停用或卸载插件时终止子进程；宿主进程异常退出时，鲸鱼通过父进程检测自行退出。
- **单实例保护**：同一 Windows 会话中只保留一个鲸鱼实例。

## 环境要求

- Windows 的交互式桌面会话，能够运行 `powershell.exe`（Windows PowerShell 5.1）。
- 可用的 .NET Framework/WPF 组件；脚本启动时会通过 `Add-Type` 编译随包的 C# 边界窗口类。
- 已安装 DeepSeek Harness；Host 进程能够启动本地子进程并读写用户应用数据目录。
- CLI 安装需要 Git 和可用的 Harness 插件管理环境。

插件自身不需要 API Key，不调用模型或网络服务。它读取桌面工作区和窗口位置，将位置保存在本地；不要在没有交互桌面的服务或无界面服务器中运行。

## 安装与启用

以下命令在 **PowerShell** 中执行，使用 Harness 官方 CLI 的 profile 插件管理入口：

```powershell
git clone https://github.com/fxy0715/dsh-pet-desktop.git
cd dsh-pet-desktop

$pluginPath = (Get-Location).Path
dsh plugin --profile web add "$pluginPath"
dsh web
```

`dsh` 表示你已安装的 Harness CLI。若从 Harness 源码运行，请在 Harness 仓库内使用 `pnpm dsh`，并传入插件目录的绝对路径；使用其他 profile 时替换 `web`。

安装会修改目标 profile 的插件依赖和 Bundle 列表。请先停止已有的对应 profile，安装后重新启动。鲸鱼运行在 **Harness Host 所在的 Windows 桌面**，不是远程浏览器所在的电脑。

仓库已经包含运行所需的 `index.js`、`whale.ps1`、`ScreenBoundWindow.cs` 和图标，安装使用无需先执行 `pnpm build`。插件目录安装后应保持路径稳定，移动目录后需重新安装。

## 交互说明

| 操作 | 结果 |
| --- | --- |
| 首次启动 | 默认出现在当前工作区右下角；存在保存位置时尝试恢复 |
| 左键单击 | 显示短暂气泡并摇摆 |
| 左键拖动 | 移动鲸鱼并保存位置；松开后短暂等待再继续游动 |
| 右键 → 暂停游走 / 恢复游走 | 切换自动漫游；上下浮动动画仍会保留 |
| 右键 → 回到右下角 | 归位、清除保存位置并恢复游走 |
| 右键 → 退出 | 关闭本次鲸鱼窗口；下次重新加载插件时可再次启动 |

通过 Harness 停用或卸载插件会清理其子进程。如果宿主没有正常执行清理，鲸鱼每 5 秒检查一次父进程是否仍然存在。

## 位置保存与配置

默认位置文件为：

```text
%APPDATA%\dsh-pet\position.json
```

文件保存 WPF 坐标 `x`、`y`，只在手动拖动后更新。显示器布局变化时，恢复的位置会被约束到可见工作区；使用“回到右下角”会清除保存位置。

Harness Bundle 当前使用 `config: {}`，尚无可配置字段。脚本支持两个参数，供独立预览或集成使用：

| 参数 | 用途 |
| --- | --- |
| `-ParentPid` | 需要跟随的宿主 PID；默认 `0`，独立运行时不检查父进程 |
| `-StateFile` | 自定义位置文件路径；默认使用上面的应用数据路径 |

Harness 会以隐藏的 Windows PowerShell STA 进程启动脚本；启动参数中的执行策略仅作用于该子进程，不修改系统永久配置。

## 本地开发与预览

### 独立预览

在工程根目录执行下面的命令，会直接打开一个可见的鲸鱼窗口；通过右键菜单退出：

```powershell
powershell.exe -NoProfile -STA -File .\whale.ps1
```

若已通过 Harness 启动鲸鱼，单实例保护会使第二次启动直接退出。独立预览默认也使用相同的位置文件；需要隔离时可通过 `-StateFile` 指定另一个文件。

### 构建素材

`pnpm build` 仅重新注入共享鲸鱼路径并生成图标，不编译 JavaScript，也不启动桌面窗口。目前构建依赖同级的 `dsh-pet` 素材目录：

```text
plugins/
├─ dsh-pet/
│  ├─ assets/whale-path.txt
│  └─ scripts/whale-artwork.cjs
└─ dsh-pet-desktop/
   └─ scripts/build.cjs
```

准备好共享目录后，在本工程根目录执行：

```powershell
pnpm build
```

**单独克隆本仓库不包含上述共享素材，不能直接重新构建素材。** 使用已提交运行文件不受影响；仅修改 Host JavaScript、PowerShell 或 C# 逻辑时，也无需先运行素材构建。构建脚本不读取已安装应用的 `app.asar`。

| 文件 | 用途 |
| --- | --- |
| `index.js` | 启动 PowerShell 子进程、记录启动失败、注册卸载清理 |
| `whale.ps1` | WPF 界面、动画、拖拽、菜单、位置保存与父进程检测 |
| `ScreenBoundWindow.cs` | 原生窗口移动约束、显示工作区和 DPI 变化处理 |
| `scripts/build.cjs` | 读取共享素材，更新鲸鱼路径与图标 |
| `cordis.patch.yml` | 将插件加入 Harness 配置树的 Bundle patch |
| `locale/` | 插件元信息的中英文文案；桌面菜单与气泡当前为中文 |
| `icon.svg` | 插件图标 |

## 常见问题

**插件启用后看不到鲸鱼？**

确认 Host 运行在 Windows 交互式桌面，`powershell.exe` 与 WPF 可用，且没有其他实例。查看 Harness 日志中的 `[dsh-pet-desktop]` 启动或退出错误；可使用上面的独立预览命令查看脚本错误。

**拖动后找不到鲸鱼，或更换显示器后位置异常？**

优先使用右键菜单“回到右下角”。若窗口不可操作，可先关闭鲸鱼或停用插件，备份并删除上面的位置文件，再重新加载插件。

**右键退出后没有自动重新出现？**

退出只关闭本次窗口，插件没有自动重启子进程的机制。重新加载插件或重启所属 Harness profile 即可再次启动。

**为什么 `pnpm build` 报找不到 `whale-artwork.cjs`？**

构建需要上面列出的同级 `dsh-pet` 共享目录。普通安装请直接使用仓库中的现成运行文件。

## 相关项目与反馈

- [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)
- [Harness CLI 与 profile 插件管理](https://github.com/fxy0715/deepseek-harness/blob/master/apps/cli/README.zh.md)
- [dsh-composer-clock：输入框时钟](https://github.com/fxy0715/dsh-composer-clock)
- [提交问题或建议](https://github.com/fxy0715/dsh-pet-desktop/issues)；请附上 Windows 与 Harness 版本、显示器缩放、复现步骤和相关日志。

鲸鱼形象来自 DeepSeek 品牌素材；本仓库是独立的插件项目。
