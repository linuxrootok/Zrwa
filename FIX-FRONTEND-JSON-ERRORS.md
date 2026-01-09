# 前端和 JSON 序列化错误修复说明

## 修复的问题

### 1. 首页显示 "Frontend placeholder"
**原因：**
- 前端构建目录 `frontend/build` 不存在或为空时，创建了占位文件
- 条件构建逻辑可能导致前端未构建

**修复：**
- ✅ 改进前端构建检查逻辑：如果构建目录不存在，强制重新构建
- ✅ 移除占位文件创建逻辑，改为构建失败时报错
- ✅ 确保前端文件上传前清空目标目录
- ✅ 添加目录列表验证，确保文件正确上传

### 2. LocalDateTime JSON 序列化错误
**原因：**
- Java 8 的 `LocalDateTime` 需要 Jackson JSR310 模块支持
- Spring Boot 2.7.18 默认不包含该模块

**修复：**
- ✅ 添加 `jackson-datatype-jsr310` 依赖到 `pom.xml`
- ✅ 在 `Application.java` 中配置 `ObjectMapper` 注册 `JavaTimeModule`
- ✅ 在 `application.properties` 中配置 Jackson 序列化选项

## 修改的文件

1. **backend/pom.xml**
   - 添加 `jackson-datatype-jsr310` 依赖

2. **backend/src/main/java/com/example/app/Application.java**
   - 添加 `ObjectMapper` Bean 配置
   - 注册 `JavaTimeModule` 支持 Java 8 时间类型

3. **backend/src/main/resources/application.properties**
   - 添加 Jackson 配置：
     - `spring.jackson.serialization.write-dates-as-timestamps=false`
     - `spring.jackson.deserialization.fail-on-unknown-properties=false`

4. **.github/workflows/deploy-fullstack.yml**
   - 改进前端构建检查逻辑
   - 移除占位文件创建，改为强制构建或报错
   - 添加文件上传验证

## 验证方法

部署后，可以通过以下方式验证：

### 1. 检查前端页面
```bash
# 访问首页，应该看到 React 应用，而不是 "Frontend placeholder"
curl http://<APP_IP>/
```

### 2. 测试 API JSON 序列化
```bash
# 获取消息，应该返回正确的 JSON（包含 createdAt 字段）
curl http://<APP_IP>/api/messages

# 创建消息
curl -X POST http://<APP_IP>/api/messages \
  -H "Content-Type: application/json" \
  -d '{"content":"Test message"}'
```

### 3. 检查前端构建
```bash
# 在 GitHub Actions 日志中查看前端构建步骤
# 应该看到 "✅ Frontend built" 而不是占位文件警告
```

## 预期结果

- ✅ 首页显示 React 应用界面
- ✅ `/api/messages` 返回正确的 JSON，包含 `createdAt` 字段（ISO 8601 格式）
- ✅ 前端构建始终成功，不会创建占位文件
- ✅ JSON 序列化不再出现错误

## 注意事项

1. **前端构建**：确保 `frontend/build` 目录在部署前存在且包含文件
2. **JSON 格式**：`createdAt` 字段现在以 ISO 8601 格式返回（例如：`2026-01-09T18:04:24`）
3. **依赖更新**：需要重新构建后端 WAR 文件以包含新的 Jackson 依赖

