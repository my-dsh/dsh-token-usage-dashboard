# dsh-token-usage-dashboard

[English](README.en.md) | 中文

[DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) 的跨会话 Token 用量看板插件。

该插件从模型调用流中捕获每次请求的 Token 用量，持久化到 SQLite 数据库，并在 Web GUI 中渲染一个浮动看板面板，展示每日按 `(provider, model)` 分组的汇总数据：Token 桶、吞吐量、TTFT、LLM 步骤耗时和缓存命中率。

![Token 消费看板：按供应商与模型分组的当日汇总，含 Token 桶、缓存命中率、TTFT 与耗时 KPI](docs/dashboard.png)

## 架构

三个包组成完整功能：

| 包 | 名称 | 角色 |
|---|---|---|
| `host/` | `@deepseek-ai/dsh-token-usage` | Session/event 监听器，捕获每次请求的用量记录，暴露基于 SQLite 的 `TokenUsageStore` Service Definition |
| `client/` | `@deepseek-ai/dsh-client-token-usage` | 浏览器看板面板，注册到 `shell.overlay`——一个悬浮按钮打开每日汇总的模态面板 |
| `bundle/` | `@deepseek-ai/dsh-token-usage-dashboard` | Profile bundle：一个 `cordis.patch.yml` 插入全部四行（SQLite provider + 捕获监听器 + Remote 服务 + 浏览器面板） |

### 数据流

```
模型调用 → session/event 监听器 → TokenUsageStore.append(record)
                                    ↓
                               SQLite 数据库
                                    ↓
                        TokenUsageRemoteService.dailySummary(date, timeZone)
                                    ↓  (Typert Remote RPC)
                        浏览器面板 (shell.overlay 入口)
```

捕获监听器通过共享的 `@deepseek-ai/dsh-step-timing` 原语折叠步骤边界（`step/start` → 首 token → `assistant/message`），因此 TTFT 和 decode 时长与会话作用域投影一致。浏览器面板每次请求携带本地时区（`browserTimeZone`），宿主据此用同一时区界定当日边界。

## 安装

```sh
dsh plugin --profile <name> add github:my-dsh/dsh-token-usage-dashboard#dist
```

包声明了 `dsh.bundle`，安装后自动加入 profile 的 bundle 层栈，重启 DSH 生效。

面板仅在 web 界面中渲染，因此目标 profile 必须已提供 client 运行时、连接和 `shell.overlay` 布局。需要 `pnpm` 在 `PATH` 上。

### SQLite 路径

默认数据库位置为 DSH 主目录下的 `token-usage.sqlite`。可通过配置覆盖：

```yaml
- id: token-usage-sqlite
  name: '@deepseek-ai/dsh-token-usage/sqlite-provider'
  config:
    path: /自定义路径/token-usage.sqlite
```

## 用法

采集在下次启动时开始，无需配置：每次成功的模型调用追加一条记录。从 shell 右下角的悬浮按钮打开看板，选择日期后刷新。

Store 从不自动删除；`tokenUsage.purge(before?)` 删除某个 epoch 毫秒时间戳之前的行，用于保留策略。

## 源码布局

```
dsh-token-usage-dashboard/
├── host/
│   ├── src/
│   │   ├── index.ts           # Session/event 捕获监听器
│   │   ├── store.ts           # TokenUsageStore Service Definition + SqliteTokenUsageStore
│   │   ├── sqlite-provider.ts # 挂载 SQLite store 的 Cordis 插件
│   │   ├── remote.ts          # Typert Remote 服务 (dailySummary, purge)
│   │   ├── types.ts           # UsageRecord, DailySummary 类型
│   │   ├── types.d.ts         # 生成的类型声明
│   │   ├── invariant.ts       # 包不变量伴随
│   │   └── ...
│   └── package.json
├── client/
│   ├── src/
│   │   ├── index.ts           # Host 加载入口（空 apply）
│   │   ├── invariant.ts       # 包不变量伴随
│   │   ├── client/
│   │   │   ├── index.ts       # 浏览器插件：shell.overlay 注册
│   │   │   ├── slots.ts       # Inject face + Remote API 调用
│   │   │   ├── TokenUsageDashboard.tsx  # 看板面板组件
│   │   │   ├── format.ts      # 数字/日期格式化
│   │   │   ├── locales.ts     # 中文 locale 字典
│   │   │   └── ...
│   │   └── ...
│   └── package.json
├── bundle/
│   ├── cordis.patch.yml       # 4 行插入：provider + 监听器 + remote + 面板
│   ├── src/
│   │   ├── index.ts           # 空壳 carrier
│   │   └── invariant.ts       # Bundle 不变量伴随
│   └── package.json
└── package.json               # 根 workspace
```

## 依赖

该插件依赖以下 DSH 包（从 DSH monorepo 安装）：

- `@deepseek-ai/cordis` — Cordis 插件框架
- `@deepseek-ai/dsh-session` — Session 事件和类型
- `@deepseek-ai/dsh-llm` — LLM 消息工具
- `@deepseek-ai/dsh-step-timing` — 步骤边界计时原语
- `@deepseek-ai/dsh-zoned-time` — 时区日分桶
- `@deepseek-ai/dsh-typert-protocol` — Typert Remote 协议
- `@deepseek-ai/dsh-api-remotes` — Remote 客户端组装
- `@deepseek-ai/dsh-client-ui-layout` — `shell.overlay` slot 声明者
- `@deepseek-ai/dsh-client-ui-renderer` — Slot registry 服务
- `@deepseek-ai/dsh-client-locale` — Locale 服务

## 许可证

MIT
