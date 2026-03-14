FROM rocker/r-ver:4

# 使用 Posit 预编译二进制包（秒装，无需编译）
RUN install2.r --error --skipmissing \
    plumber nanoparquet readxl jsonlite

WORKDIR /app

# 复制 API 逻辑和数据文件
COPY api.R start_api.R ./
COPY ["Slide 4 Origination Trends.xlsx", "./data/"]

# 默认环境变量
ENV DATA_DIR=/app/data \
    API_HOST=0.0.0.0 \
    API_PORT=8000

EXPOSE 8000

CMD ["Rscript", "start_api.R"]
