# 启动 Plumber API 服务
library(plumber)

host <- Sys.getenv("API_HOST", "0.0.0.0")
port <- as.integer(Sys.getenv("API_PORT", "8000"))

root <- pr()                    # 空的根路由器
api  <- plumb("api.R")          # 业务路由器
root$mount("/analyst", api)     # 整体挂载到 /analyst

# 将 /analyst/__docs__/* 和 /analyst/openapi.json 重写到根路径，
# 使内置 Swagger UI 可通过 /analyst/__docs__/ 访问
root$filter("docs-rewrite", function(req) {
  if (grepl("^/analyst/(__docs__|openapi\\.json)", req$PATH_INFO)) {
    req$PATH_INFO <- sub("^/analyst", "", req$PATH_INFO)
  }
  forward()
})

root$run(host = host, port = port)
