# --- 基础阶段 (Base Stage) ---
# 使用 Alpine 版本保持镜像小巧
# better-sqlite3 需要编译，所以需要安装构建工具
FROM node:20-alpine AS base

# 安装 better-sqlite3 编译依赖
RUN apk add --no-cache python3 make g++

# 设置工作目录
WORKDIR /usr/src/app


# --- 依赖阶段 (Dependencies Stage) ---
FROM base AS dependencies

# 复制 package.json 和 package-lock.json
COPY package.json package-lock.json* ./

# 安装生产环境依赖（包括编译 better-sqlite3）
RUN npm install --only=production


# --- 生产/运行阶段 (Production/Runtime Stage) ---
FROM node:20-alpine AS production

# 设置环境变量
ENV NODE_ENV=production

# 设置工作目录
WORKDIR /usr/src/app

# 从依赖阶段复制 node_modules
COPY --from=dependencies /usr/src/app/node_modules ./node_modules

# 复制源代码和配置文件
COPY src ./src
COPY scripts ./scripts
COPY package.json ./
COPY schema.sql ./

# 创建数据目录（用于存放 SQLite 数据库文件）
RUN mkdir -p /usr/src/app/data

# 创建非 root 用户运行应用
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# 设置目录权限
RUN chown -R appuser:appgroup /usr/src/app

# 切换到非 root 用户
USER appuser

# 暴露端口
EXPOSE 8045

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8045/v1/models || exit 1

# 启动命令
CMD [ "node", "src/server/index.js" ]
