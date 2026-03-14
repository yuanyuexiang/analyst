# ============================================================
# api.R — Plumber API 服务（源码不分发，仅在服务器运行）
# ============================================================

library(nanoparquet)
library(readxl)
library(jsonlite)

# 数据目录
DATA_DIR <- Sys.getenv("DATA_DIR", ".")
DEFAULT_EXCEL   <- file.path(DATA_DIR, "Slide 4 Origination Trends.xlsx")

# ---- 内部函数（不对外暴露） ----

.read_excel <- function(file_path = DEFAULT_EXCEL, sheet = NULL) {
  if (is.null(sheet)) {
    sheet <- readxl::excel_sheets(file_path)[1]
  }
  as.data.frame(readxl::read_excel(file_path, sheet = sheet))
}

.get_metrics_colname <- function(df) {
  idx <- which(tolower(colnames(df)) == "metrics")
  if (length(idx) == 0) {
    return(NULL)
  }
  colnames(df)[idx[1]]
}

.parse_head <- function(head) {
  if (is.null(head)) {
    return(NULL)
  }
  n <- suppressWarnings(as.integer(head))
  if (is.na(n) || n < 1) {
    stop("`head` must be a positive integer.", call. = FALSE)
  }
  n
}

.parse_metrics <- function(metric = NULL) {
  if (is.null(metric)) {
    return(character(0))
  }
  vals <- as.character(metric)
  vals <- unlist(strsplit(vals, ",", fixed = TRUE), use.names = FALSE)
  vals <- trimws(vals)
  vals <- vals[vals != ""]
  unique(vals)
}

# ---- API 端点 ----

#* 健康检查
#* @get /api/v1/health
function() {
  list(status = "ok", timestamp = Sys.time())
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

#* 列出 Metrics 分类值
#* @param sheet 工作表名称（可选，默认第一个）
#* @param file_path 文件路径（可选）
#* @serializer json
#* @get /api/v1/excel/metrics/list
function(sheet = NULL, file_path = NULL) {
  fp <- if (!is.null(file_path)) file_path else DEFAULT_EXCEL
  df <- .read_excel(fp, sheet)
  metrics_col <- .get_metrics_colname(df)
  if (is.null(metrics_col)) {
    stop("Column `Metrics` not found in the selected sheet.", call. = FALSE)
  }

  vals <- unique(as.character(df[[metrics_col]]))
  vals <- vals[!is.na(vals) & trimws(vals) != ""]
  vals <- sort(vals)
  list(metrics = vals, count = length(vals))
}

#* 按 Metrics 分类读取 Excel
#* @param metric 分类值（可选；支持单个值或逗号分隔多个值，不传则返回全部分类）
#* @param sheet 工作表名称（可选，默认第一个）
#* @param file_path 文件路径（可选）
#* @param head 只返回前 N 行（可选）
#* @serializer json
#* @get /api/v1/excel/metrics
function(metric = NULL, sheet = NULL, file_path = NULL, head = NULL) {
  fp <- if (!is.null(file_path)) file_path else DEFAULT_EXCEL
  df <- .read_excel(fp, sheet)
  metrics_col <- .get_metrics_colname(df)
  if (is.null(metrics_col)) {
    stop("Column `Metrics` not found in the selected sheet.", call. = FALSE)
  }

  n <- .parse_head(head)

  mvals <- as.character(df[[metrics_col]])
  keep <- !is.na(mvals) & trimws(mvals) != ""
  df <- df[keep, , drop = FALSE]
  selected_metrics <- .parse_metrics(metric)

  if (length(selected_metrics) > 0) {
    df <- df[as.character(df[[metrics_col]]) %in% selected_metrics, , drop = FALSE]
    split_rows <- split(df, as.character(df[[metrics_col]]))
    if (!is.null(n)) {
      split_rows <- lapply(split_rows, function(x) utils::head(x, n))
    }
    return(list(
      metrics = names(split_rows),
      grouped = split_rows,
      count = length(split_rows),
      #row_count = nrow(df)
    ))
  }

  split_rows <- split(df, as.character(df[[metrics_col]]))
  if (!is.null(n)) {
    split_rows <- lapply(split_rows, function(x) utils::head(x, n))
  }

  list(
    metrics = names(split_rows),
    grouped = split_rows,
    count = length(split_rows)
  )
}
