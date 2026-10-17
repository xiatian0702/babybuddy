# 服务器 Docker 部署说明

目标服务器：`xiatian`（`/workspace/babybuddy`），代码来自
`git@github.com:xiatian0702/babybuddy.git` 的 `master` 分支。

## 架构

```
浏览器 -> nginx 容器 :80 -> web 容器 (gunicorn 0.0.0.0:8000) -> Django (SQLite)
                   |-> /static/  /workspace/babybuddy/static
                   |-> /media/   /workspace/babybuddy/media
```

- 源码以 bind mount 方式挂载进 `web` 容器（`./:/app`），服务器上的
  `/workspace/babybuddy` 就是运行中的代码，没有额外拷贝。
- 数据库：`data/db.sqlite3`；上传文件：`media/`（都在宿主机上，pull 不会覆盖）。
- 环境变量：`.env`（首次安装自动生成，已被 git 忽略）。
- `git pull` 更新 `master` 后，systemd path 单元监听到 ref 变化，自动执行
  `deploy/deploy.sh`：依赖变化时重建镜像，然后重启 `web` 容器；容器入口会先
  执行 `manage.py migrate`。
- 静态文件由 `nginx` 容器直接读取挂载的 `static/` 目录，不经过 Django。

## 首次安装

```bash
ssh xiatian
git clone git@github.com:xiatian0702/babybuddy.git /workspace/babybuddy
/workspace/babybuddy/deploy/install.sh
```

基础镜像 `python:3.12-slim` 和 `nginx:alpine` 已从本地 WSL 通过
`docker save` / `docker load` 导入服务器；`install.sh` 只在镜像缺失时才尝试
从镜像源拉取。

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

pull 完成后几秒内 `web` 容器会自动重启，无需手工操作。日志：

```bash
journalctl -u babybuddy-deploy -n 50   # 最近一次部署
cd /workspace/babybuddy && docker compose logs -f web
```

## 常用命令

```bash
cd /workspace/babybuddy
docker compose ps
docker compose logs -f web nginx
docker compose restart web
docker compose up -d --remove-orphans
```

## 注意

- 云服务器安全组需要放行 80 端口（如需 HTTPS 再放行 443）。
- 前端静态资源（`static/` 下的构建产物）随仓库提交。如果只改了 SCSS/JS 源码，
  需要本地执行 `npm ci && npx gulp build` 并把生成的 `static/` 一并提交。
- 宿主机上的 nginx 服务会被停用，因为 `nginx` 容器占用了 80 端口。
- 如启用 HTTPS，请在 `.env` 中设置 `CSRF_TRUSTED_ORIGINS`、`SESSION_COOKIE_SECURE=1`、
  `CSRF_COOKIE_SECURE=1`、`SECURE_PROXY_SSL_HEADER=1`。
