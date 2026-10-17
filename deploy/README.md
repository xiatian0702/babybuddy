# 服务器部署说明

目标服务器：`xiatian`（`/workspace/babybuddy`），代码来自
`git@github.com:xiatian0702/babybuddy.git` 的 `master` 分支。

## 架构

```
浏览器 -> nginx :80 -> gunicorn 127.0.0.1:8000 -> Django (SQLite)
                   |-> /static/  /workspace/babybuddy/static
                   |-> /media/   /workspace/babybuddy/media
```

- 代码就是 `/workspace/babybuddy` 这份 checkout，没有额外拷贝。
- 数据库：`/workspace/babybuddy/data/db.sqlite3`（已被 git 忽略，pull 不会覆盖）。
- 环境变量：`/workspace/babybuddy/.env`（首次安装自动生成，已被 git 忽略）。
- `git pull` 更新 `master` 后，systemd path 单元监听到 ref 变化，自动执行
  `deploy/deploy.sh`：按需安装依赖、执行 migrate、重启 `babybuddy.service`。

## 首次安装

```bash
ssh xiatian
git clone git@github.com:xiatian0702/babybuddy.git /workspace/babybuddy
/workspace/babybuddy/deploy/install.sh
```

安装脚本会：安装 `python3-venv`/`nginx`、创建 `.venv`、安装依赖、生成 `.env`、
安装并启用 systemd 单元、配置 nginx。

默认登录账号是 `admin` / `admin`（由 `manage.py migrate` 创建），登录后请立即修改密码。

## 日常发布流程

本地修改并提交：

```bash
git add .
git commit -m "..."
git push origin master
```

服务器更新：

```bash
ssh xiatian
cd /workspace/babybuddy
git pull
```

pull 完成后几秒内服务会自动重启，无需手工操作。日志：

```bash
journalctl -u babybuddy-deploy -n 50   # 最近一次部署
journalctl -u babybuddy -f             # 应用日志
```

## 常用命令

```bash
systemctl status babybuddy babybuddy-deploy.path
systemctl restart babybuddy
nginx -t && systemctl reload nginx
```

## 注意

- 云服务器安全组需要放行 80 端口（如需 HTTPS 再放行 443）。
- 前端静态资源（`static/` 下的构建产物）是随仓库提交的。如果只改了 SCSS/JS
  源码，需要本地执行 `npm ci && npx gulp build` 并把生成的 `static/` 一并提交，
  服务器不会在 pull 时重新构建。
- 如启用 HTTPS，请在 `.env` 中设置 `CSRF_TRUSTED_ORIGINS`、`SESSION_COOKIE_SECURE=1`、
  `CSRF_COOKIE_SECURE=1`、`SECURE_PROXY_SSL_HEADER=1`。
