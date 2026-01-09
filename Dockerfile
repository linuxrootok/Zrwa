# 使用官方 Nginx 镜像
FROM nginx:alpine

# 复制自定义 Nginx 配置
COPY nginx.conf /etc/nginx/conf.d/default.conf

# 复制网站内容
COPY index.html /usr/share/nginx/html/index.html

# 暴露端口 80
EXPOSE 80

# Nginx 默认启动命令
CMD ["nginx", "-g", "daemon off;"]


