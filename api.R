# ============================================================
# api.R — Plumber API 服务（源码不分发，仅在服务器运行）
# ============================================================

library(nanoparquet)
library(readxl)
library(jsonlite)

# 数据目录
DATA_DIR <- Sys.getenv("DATA_DIR", ".")
DEFAULT_PARQUET <- file.path(DATA_DIR, "46681cad-347d-4c29-b139-f8ef09898c64.parquet")
DEFAULT_EXCEL   <- file.path(DATA_DIR, "Slide 4 Origination Trends.xlsx")

# ---- 内部函数（不对外暴露） ----

.read_parquet <- function(file_path = DEFAULT_PARQUET) {
  as.data.frame(nanoparquet::read_parquet(file_path))
}

.read_excel <- function(file_path = DEFAULT_EXCEL, sheet = NULL) {
  if (is.null(sheet)) {
    sheet <- readxl::excel_sheets(file_path)[1]
  }
  as.data.frame(readxl::read_excel(file_path, sheet = sheet))
}

# ---- API 端点 ----

#* 健康检查
#* @get /api/v1/health
function() {
  list(status = "ok", timestamp = Sys.time())
}

#* 读取 Parquet 文件，返回 JSON
#* @param file_path 文件路径（可选）
#* @param head 只返回前 N 行（可选）
#* @serializer json
#* @get /api/v1/parquet
function(file_path = NULL, head = NULL) {
  fp <- if (!is.null(file_path)) file_path else DEFAULT_PARQUET
  df <- .read_parquet(fp)
  if (!is.null(head)) {
    n <- as.integer(head)
    df <- utils::head(df, n)
  }
  df
}

#* 获取 Parquet 文件元信息
#* @param file_path 文件路径（可选）
#* @serializer json
#* @get /api/v1/parquet/info
function(file_path = NULL) {
  fp <- if (!is.null(file_path)) file_path else DEFAULT_PARQUET
  df <- .read_parquet(fp)
  list(
    nrow = nrow(df),
    ncol = ncol(df),
    colnames = colnames(df),
    dtypes = sapply(df, class, USE.NAMES = TRUE)
  )
}

#* 列出 Excel 工作表
#* @param file_path 文件路径（可选）
#* @serializer json
#* @get /api/v1/excel/sheets
function(file_path = NULL) {
  fp <- if (!is.null(file_path)) file_path else DEFAULT_EXCEL
  list(sheets = readxl::excel_sheets(fp))
}

#* 读取 Excel 指定工作表
#* @param sheet 工作表名称（可选，默认第一个）
#* @param file_path 文件路径（可选）
#* @param head 只返回前 N 行（可选）
#* @serializer json
#* @get /api/v1/excel
function(sheet = NULL, file_path = NULL, head = NULL) {
  fp <- if (!is.null(file_path)) file_path else DEFAULT_EXCEL
  df <- .read_excel(fp, sheet)
  if (!is.null(head)) {
    n <- as.integer(head)
    df <- utils::head(df, n)
  }
  df
}

#* 获取 Excel 文件元信息
#* @param file_path 文件路径（可选）
#* @serializer json
#* @get /api/v1/excel/info
function(file_path = NULL) {
  fp <- if (!is.null(file_path)) file_path else DEFAULT_EXCEL
  sheets <- readxl::excel_sheets(fp)
  info <- list()
  for (s in sheets) {
    df <- readxl::read_excel(fp, sheet = s)
    info[[s]] <- list(
      nrow = nrow(df),
      ncol = ncol(df),
      colnames = colnames(df)
    )
  }
  info
}
