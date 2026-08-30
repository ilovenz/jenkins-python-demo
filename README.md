# Jenkins + Python + Docker + GitHub 3 天实战包

面向：Windows 11 + WSL2 Ubuntu。目标不是“精通企业 Jenkins”，而是 2–3 天内亲手打通：

`git push` → 自动测试 → 构建镜像 → 推 Docker Hub → 部署 staging

所有命令默认在 **WSL Ubuntu 终端**里执行，不要在 PowerShell 里混跑。

---

## 0. 开始前 30 分钟（只选一条 Docker 路线）

Windows 上最容易失败的原因：Docker Desktop 和 WSL 里再装一套 Docker Engine **同时存在**。只留一套。

### 路线 A（推荐，更省事）：Docker Desktop + WSL2 后端

1. 安装 Docker Desktop，Settings → General 打开 Use WSL 2 based engine。
2. Settings → Resources → WSL integration，打开你的 Ubuntu 发行版。
3. 不要在 Ubuntu 里再 `apt install docker-ce`。
4. 打开 Ubuntu 终端验证：

```bash
docker version
docker compose version
```

### 路线 B：只用 WSL 里的 Docker Engine（不装 Desktop）

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
# 退出 Ubuntu 窗口再开一次
sudo service docker start   # 若已开 systemd 则用: sudo systemctl enable --now docker
docker version
```

验证必须两边都成功：

```bash
docker run --rm hello-world
```

再装 Git（WSL 里）：

```bash
sudo apt update && sudo apt install -y git curl
git config --global user.name "你的名字"
git config --global user.email "你的邮箱"
```

浏览器以后访问 Jenkins：`http://localhost:8080`

---

## 第 1 天：把 Jenkins 跑起来 + 第一条流水线

### 1.1 启动 Jenkins

把本目录拷到 WSL 家目录，例如：

```bash
mkdir -p ~/code && cd ~/code
# 把 jenkins-python-cicd 放到这里
cd ~/code/jenkins-python-cicd
```

启动：

```bash
cd jenkins
docker compose up -d --build
docker compose logs -f jenkins
```

另开一个终端取初始密码：

```bash
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

打开 http://localhost:8080

- 粘贴密码
- 装推荐插件即可（自定义镜像已预装 Pipeline / Git / Docker / Pipeline Graph View）
- 创建管理员账号

不要装 Blue Ocean（2026 年 7 月起弃用）。看流水线用 Pipeline Graph View。

### 1.2 确认容器能调用 Docker

```bash
docker exec jenkins docker version
docker exec jenkins docker ps
```

能列出容器就说明 Docker socket 挂载成功。

### 1.3 先在本机跑通 Python 项目

```bash
cd ~/code/jenkins-python-cicd
docker run --rm -v "$PWD":/app -w /app python:3.12-slim \
  bash -lc "pip install -r requirements.txt -r requirements-dev.txt && pytest -q"

docker build -t jenkins-python-demo:local .
docker run --rm -p 5000:5000 jenkins-python-demo:local
```

浏览器打开 http://localhost:5000/health ，应返回 `{"status":"healthy"}`。Ctrl+C 停掉。

### 1.4 在 Jenkins 里建第一条“内嵌脚本”流水线

Jenkins 首页 → New Item → 名称 `python-demo-inline` → Pipeline → OK。

Pipeline script 贴：

```groovy
pipeline {
  agent any
  stages {
    stage('Test') {
      steps {
        sh '''
          docker run --rm python:3.12-slim python -c "print('jenkins + python ok')"
        '''
      }
    }
  }
}
```

点 Build Now。成功 = 第 1 天过关。

当天要能讲清楚：

- Controller 负责调度，真正命令跑在 Agent（现在 Agent 就是这台 Jenkins 容器）
- Declarative Pipeline 的 `pipeline / agent / stages / steps`
- 为什么后面要把脚本存进 Git，而不是留在界面里

---

## 第 2 天：GitHub + Jenkinsfile + 凭据 + 镜像

### 2.1 推到 GitHub

先改 `Jenkinsfile` 里这一行，换成你的 Docker Hub 仓库：

```
IMAGE_NAME = '你的DockerHub用户名/jenkins-python-demo'
```

```bash
cd ~/code/jenkins-python-cicd
git init
git add .
git commit -m "init python jenkins demo"
git branch -M main
# 在 GitHub 新建空仓库后再执行
git remote add origin https://github.com/你的用户名/jenkins-python-demo.git
git push -u origin main
```

Windows 克隆仓库时如果曾把 CRLF 混进去，本仓库已有 `.gitattributes` 强制 LF。Jenkins 里的 `sh` 最怕 CRLF。

### 2.2 在 Jenkins 里加 Docker Hub 凭据

1. Docker Hub 建仓库 `jenkins-python-demo`（Public 即可）。
2. 建议用 Access Token，不要用登录密码。
3. Jenkins → Manage Jenkins → Credentials → (global) → Add Credentials
   - Kind: Username with password
   - Username: Docker Hub 用户名
   - Password: Access Token
   - ID: **`dockerhub`**（必须和 Jenkinsfile 里的 credentialsId 一致）

### 2.3 建 Pipeline from SCM

New Item → `python-demo` → Pipeline

- Definition: Pipeline script from SCM
- SCM: Git
- Repository URL: 你的 GitHub HTTPS 地址
- Branch: `*/main`
- Script Path: `Jenkinsfile`

私有仓库还要再加一个 GitHub PAT 凭据。公开仓库可先不配。

### 2.4 本地 Jenkins 怎么被 GitHub 触发

GitHub Webhook **打不到**你电脑的 `localhost:8080`。学习阶段用下面任一方式：

1. 在 Job 里点 Build Now（最稳）
2. Job → Configure → Build Triggers → Poll SCM，填 `H/2 * * * *`（约每 2 分钟看一次 Git）
3. 有余力再用 ngrok 把 8080 暴露出去接 Webhook（第 3 天可选）

推代码：

```bash
# 故意改一句
# app.py 里 message 改成 hello from day2
git add app.py && git commit -m "day2: change message" && git push
```

然后在 Jenkins 里构建。打开 Pipeline Graph / Console Output。

### 2.5 当天必须亲手做一次“失败构建”

把 `tests/test_app.py` 里断言改错，push，确认 Test 阶段变红。再改回来。

不会看失败日志 = 还没学会 Jenkins。

---

## 第 3 天：CD + 多分支 + 把整条链路讲出来

### 3.1 看懂今天这条流水线在干什么

| Stage | 作用 |
|---|---|
| Checkout | 拉当前提交 |
| Test | 用官方 Python 镜像跑 pytest，不把 Python 装进 Jenkins |
| Build image | `docker build` |
| Push image | 仅 main 分支，推 `:BUILD_NUMBER` 和 `:staging` |
| Deploy staging | 本机 `docker compose` 把服务挂到 **5001** |
| Approve production | `input` 人工确认，学习阶段点 Abort |
| Deploy production | 只 echo，避免误推生产 |

Staging 验证：

```bash
curl http://localhost:5001/health
```

若 Jenkins 容器内 curl 失败、你在 WSL 里却能通，那是容器访问宿主机端口的问题。compose 已加 `host.docker.internal`。仍失败就在 WSL 里手动 curl 即可，不影响学习。

### 3.2 Multibranch Pipeline

New Item → `python-demo-mb` → Multibranch Pipeline

- Branch Sources → GitHub 或 Git
- 填仓库
- Scan

然后：

```bash
git checkout -b feature/hello
# 改 app.py
git add app.py && git commit -m "feature" && git push -u origin feature/hello
```

预期：

- 功能分支会跑 Test / Build
- **不会** Push / Deploy（Jenkinsfile 里用了 `when { branch 'main' }`）

这就是主干发布、分支只验证的最小模型。

### 3.3 可选：Webhook

```bash
# WSL
ngrok http 8080
```

GitHub 仓库 → Settings → Webhooks → Payload URL:

`https://xxxx.ngrok-free.app/github-webhook/`

Content type: `application/json`

Jenkins Job 勾选 GitHub hook trigger for GITScm polling。

### 3.4 当天收尾自测

能当面讲清楚这 6 句就算这轮达标：

1. CI 是 Test + Build；CD 是 Push + Deploy staging。
2. 密钥只存在 Credentials，ID 是 `dockerhub`。
3. 本地 Jenkins 默认接不到 GitHub Webhook，所以用轮询或手动构建。
4. Multibranch 让每个分支用同一份 Jenkinsfile，用 `when` 区分是否发布。
5. `input` 会占用构建，没人点就卡着。
6. 挂载 docker.sock 是学习方案，生产更常见的是独立 Agent 或 Kubernetes 动态 Agent。

---

## 常见故障（Windows + WSL 几乎都会遇到）

| 现象 | 处理 |
|---|---|
| `docker: command not found`（在 Jenkins 日志里） | 确认用的是 `jenkins/docker-compose.yml` 构建出的镜像，不是裸 `jenkins/jenkins` |
| `permission denied /var/run/docker.sock` | compose 里已用 `user: root`。仍失败则检查 WSL 里 `ls -l /var/run/docker.sock` |
| 插件页面一直转圈 | 等 2 分钟，或 `docker compose restart jenkins` |
| `pytest` 找不到 `app` | 测试要用 `docker run -v "$PWD":/app -w /app`，工作目录必须是仓库根 |
| GitHub 推了但 Jenkins 没动 | 本地没有公网，改用 Poll SCM 或手动 Build |
| `sh` 报 `bad interpreter` / `\r` | 全在 WSL 里 git 操作，不要用 Windows 记事本改 Jenkinsfile |
| 8080 打不开 | `docker ps` 看端口；Windows 浏览器访问 localhost 即可，不必在 WSL 里开浏览器 |
| Desktop 和 WSL Engine 抢 Docker | 卸掉其中一套，`which docker` 只应指向一个 |

停掉 / 清数据：

```bash
cd ~/code/jenkins-python-cicd/jenkins
docker compose down          # 保留数据
docker compose down -v       # 连 Jenkins 配置一起删，等于重装
```

---

## 不在这 3 天范围里的事

- Kubernetes Agent / Helm 发布
- Shared Library
- JCasC 全量配置
- Jenkins 高可用
- 把 docker.sock 用于公司生产

先把这一条 Python 流水线跑稳，再加这些。
