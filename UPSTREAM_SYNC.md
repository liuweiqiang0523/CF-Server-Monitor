# 上游自动同步

本 Fork 使用 `.github/workflows/upstream-sync.yml` 每天从
`huilang-me/CF-Server-Monitor` 的 `main` 分支同步一次，也可以在 Actions 页面手动运行。

同步策略如下：

- 上游提交可直接包含当前 Fork 时执行 fast-forward；
- Fork 有自己的提交时，创建普通 merge commit，保留 Fork 的自定义修改；
- 出现冲突时停止并报错，不强制覆盖任何代码，需要手动解决后重新运行；
- 同步产生的新提交会触发 Cloudflare Git 集成；如果配置了 `CF_ACCOUNT_ID`，工作流还会显式触发仓库内的 `deploy.yml`。

首次启用前请确认：

1. 仓库 `Settings → Actions → General` 已启用 Actions；
2. `Workflow permissions` 选择 **Read and write permissions**，或由工作流中的 `permissions` 配置授予写权限；
3. 如果使用 GitHub Actions 部署 Cloudflare，配置 `CF_API_TOKEN`、`CF_ACCOUNT_ID`、`D1_DATABASE_ID`、`API_SECRET` 等 Secrets；
4. 在 Actions 中手动运行一次 **Sync upstream (daily)**，确认日志显示 `Synced upstream ...`，再等待每日定时任务。

注意：GitHub 的定时任务使用 UTC，本项目设置为每天 `00:17 UTC`（北京时间每天 08:17）。
