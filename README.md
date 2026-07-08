# RAGFlow ARM64 Docker 镜像构建包

## 核心优化

**前端原生编译加速**：将前端构建阶段独立出来，使用 `--platform=$BUILDPLATFORM` 在 x86 宿主机上以原生速度编译，避免 Node.js/V8 在 QEMU 模拟下运行，构建速度提升 5~10 倍。

前端产物为纯静态 HTML/JS/CSS，与 CPU 架构完全无关，可以安全地从 x86 构建阶段复制到 ARM64 最终镜像中。

---

## 文件说明

| 文件 | 说明 |
|------|------|
| `Dockerfile.arm64-optimized` | 优化后的 Dockerfile（前端原生编译 + ARM64 适配） |
| `build-arm64.sh` | 本地一键构建脚本（需在有 Docker 的 x86 机器上运行） |
| `.github/workflows/build-arm64.yml` | GitHub Actions 自动构建工作流 |

---

## 使用方式一：GitHub Actions 自动构建（推荐）

**无需本地 Docker 环境，全程云端构建，免费**

### 操作步骤（仅需 3 分钟）

1. **创建 GitHub 仓库**
   - 新建一个公开或私有仓库（例如 `ragflow-arm64-builder`）

2. **上传文件**
   - 将本目录下的所有文件上传到仓库根目录：
     - `Dockerfile.arm64-optimized`
     - `.github/workflows/build-arm64.yml`

3. **配置 Docker Hub 凭证**
   - 进入仓库 → Settings → Secrets and variables → Actions
   - 点击 "New repository secret" 添加两个密钥：
     - `DOCKER_USERNAME`：你的 Docker Hub 用户名
     - `DOCKER_TOKEN`：Docker Hub 的 Access Token（在 Docker Hub → Account Settings → Security → New Access Token 创建）

4. **触发构建**
   - 进入仓库 → Actions → 左侧选择 "Build RAGFlow ARM64 Image"
   - 点击 "Run workflow"
   - 填写版本号（默认 `v0.26.3`），点击运行
   - 等待构建完成（约 30~60 分钟）

5. **获取镜像**
   - 构建完成后，镜像会自动推送到你的 Docker Hub
   - 镜像地址：`你的用户名/ragflow:v0.26.3-arm64`

---

## 使用方式二：本地脚本构建

在有 Docker 的 x86 机器上执行：

```bash
# 1. 设置环境变量
export DOCKER_USERNAME="你的DockerHub用户名"
export RAGFLOW_VERSION="v0.26.3"

# 2. 登录 Docker Hub
docker login

# 3. 运行构建脚本
chmod +x build-arm64.sh
./build-arm64.sh
```

### 环境要求
- x86_64 架构 Linux/macOS 机器
- Docker 20.10+
- 已启用 Docker BuildX
- 约 10GB 可用磁盘空间

---

## ARM 机器部署

构建完成后，在 ARM64 服务器上部署：

```bash
# 1. 拉取 RAGFlow 源码
git clone --depth 1 --branch v0.26.3 https://github.com/infiniflow/ragflow.git
cd ragflow/docker

# 2. 修改 .env 文件，替换镜像地址
sed -i "s|RAGFLOW_IMAGE=infiniflow/ragflow:v0.26.3|RAGFLOW_IMAGE=你的用户名/ragflow:v0.26.3-arm64|" .env

# 3. 启动服务
docker compose -f docker-compose.yml up -d
```

---

## 优化前后对比

| 阶段 | 优化前（QEMU 模拟） | 优化后（原生编译） |
|------|---------------------|-------------------|
| 前端 npm install | ~10 分钟（模拟） | ~1 分钟（原生） |
| 前端 npm run build | ~15 分钟（模拟） | ~2 分钟（原生） |
| Python 依赖安装 | QEMU 模拟 | QEMU 模拟 |
| **总前端构建耗时** | **~25 分钟** | **~3 分钟** |

整体构建时间可缩短约 40%~60%。

---

## 注意事项

1. **Infinity 引擎**：官方暂不支持 ARM64 下使用 Infinity 文档引擎，部署时保持默认 Elasticsearch 即可
2. **xgboost 版本**：ARM64 构建自动将 xgboost 降级到 1.6.0 以保证兼容性
3. **Chrome/Selenium**：ARM64 环境下浏览器自动化相关功能可能受限
4. **首次构建**：首次构建需要下载大量依赖，耗时较长，后续构建利用缓存会快很多
