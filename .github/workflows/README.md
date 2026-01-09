# GitHub Actions Workflows

## CI Workflow (ci.yml)

自动构建和测试 Docker 镜像。

### 触发条件
- Push 到 `main`、`master` 或 `develop` 分支
- 创建 Pull Request 到上述分支

### 执行步骤
1. 检出代码
2. 设置 Docker Buildx
3. 构建 Docker 镜像
4. 运行容器并测试 HTTP 响应
5. 验证输出包含 "hello, world"
6. 检查镜像大小

### 成本
- GitHub Actions 免费额度：每月 2000 分钟（私有仓库）或无限（公开仓库）
- 本 workflow 每次运行约 1-2 分钟
- **成本：$0**（在免费额度内）


