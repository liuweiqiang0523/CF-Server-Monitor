# 上游自动同步与部署

`.github/workflows/upstream-sync.yml` 每天 00:17 UTC（北京时间 08:17，GitHub 可能延迟调度）检查 `huilang-me/CF-Server-Monitor/main`，也支持 Actions 手动运行。

1. 拉取上游，无分歧时快进，有 Fork 提交时正常合并。
2. 有更新时先运行 `npm ci`、`npm run test:all`、同步脚本回归测试和前端构建，通过后才推送 main。
3. 显式触发 `deploy.yml`，等待部署结果，再核对 `https://tz.onemjj.com/api/config` 的版本。
4. 即使没有新提交，也会检查当前 main 的部署；上一次部署失败或遗漏时重新触发，而不是永久跳过。

部署使用已有的 `CF_API_TOKEN`、`CF_ACCOUNT_ID`、`D1_DATABASE_ID`、`API_SECRET` 等 Secrets。工作流需要 contents/actions 写权限；生产部署通过 concurrency 串行执行。

2026-11-15 修复了语言文件拆分造成的合并冲突：旧 Fork 的中文 `BD` 默认文案已回归上游 `BGP`。站点需要自定义标签时使用后台节点名称设置，避免继续修改上游源码。Worker 名称和 D1 绑定继续保留当前实例配置。

自动同步不强制覆盖冲突或改写 Git 历史。未来如果 Fork 与上游仍有真实冲突，任务会回滚本次合并、显示冲突文件并标记失败；上游修改 workflow 文件时，也可能受 GitHub 默认 token 的 workflow 写入限制，需要具备 workflow 权限的维护者同步。请保持 GitHub Actions 失败通知开启。GitHub 也可能因仓库长期无活动暂停定时任务；可在 Actions 页面重新启用。

本地验证：`node --test test/upstream-sync.test.js` 覆盖快进、保留 Fork 自定义修改、冲突回滚和重复运行；`bash -n scripts/sync-upstream.sh scripts/deploy-synced-main.sh` 检查 shell 语法。
