"""
api_client.py — Python 客户端，通过 HTTP 调用 R API 服务
============================================================

使用方法:
    from api_client import DataLoaderClient

    client = DataLoaderClient("http://localhost:8000")

    # 读取 Parquet 数据
    df = client.read_parquet()

    # 读取 Excel 指定工作表
    df = client.read_excel(sheet="Platform")

    # 获取文件信息
    info = client.parquet_info()
    sheets = client.excel_sheets()

依赖:
    pip install requests pandas
"""

import requests
import pandas as pd
from typing import Optional


class DataLoaderClient:
    """通过 HTTP API 调用远程 R 服务来读取数据"""

    def __init__(self, base_url: str = "http://localhost:8000"):
        self.base_url = base_url.rstrip("/")

    def _get(self, endpoint: str, params: dict = None):
        """发送 GET 请求"""
        url = f"{self.base_url}{endpoint}"
        resp = requests.get(url, params=params, timeout=30)
        resp.raise_for_status()
        return resp.json()

    def health(self) -> dict:
        """健康检查"""
        return self._get("/analyst/api/v1/health")

    def read_parquet(self, head: Optional[int] = None) -> pd.DataFrame:
        """
        读取 Parquet 文件

        Args:
            head: 只返回前 N 行（可选）

        Returns:
            pd.DataFrame
        """
        params = {}
        if head is not None:
            params["head"] = head
        data = self._get("/analyst/api/v1/parquet", params)
        return pd.DataFrame(data)

    def parquet_info(self) -> dict:
        """
        获取 Parquet 文件的元信息

        Returns:
            dict: {nrow, ncol, colnames, dtypes}
        """
        return self._get("/analyst/api/v1/parquet/info")

    def excel_sheets(self) -> list:
        """
        列出 Excel 文件的所有工作表

        Returns:
            list[str]
        """
        result = self._get("/analyst/api/v1/excel/sheets")
        return result.get("sheets", [])

    def read_excel(self, sheet: Optional[str] = None, head: Optional[int] = None) -> pd.DataFrame:
        """
        读取 Excel 指定工作表

        Args:
            sheet: 工作表名称（默认第一个）
            head: 只返回前 N 行（可选）

        Returns:
            pd.DataFrame
        """
        params = {}
        if sheet:
            params["sheet"] = sheet
        if head is not None:
            params["head"] = head
        data = self._get("/analyst/api/v1/excel", params)
        return pd.DataFrame(data)

    def excel_info(self) -> dict:
        """
        获取 Excel 文件的元信息

        Returns:
            dict: {sheet_name: {nrow, ncol, colnames}}
        """
        return self._get("/analyst/api/v1/excel/info")


# --- 直接运行时的演示 ---
if __name__ == "__main__":
    client = DataLoaderClient()

    # 健康检查
    print("健康检查:", client.health())

    # Parquet
    print("\n===== Parquet =====")
    info = client.parquet_info()
    print(f"行数: {info['nrow']}, 列数: {info['ncol']}")
    print(f"列名: {info['colnames']}")

    df = client.read_parquet(head=5)
    print(f"\n前 5 行:\n{df}")

    # Excel
    print("\n===== Excel =====")
    sheets = client.excel_sheets()
    print(f"工作表: {sheets}")

    excel_info = client.excel_info()
    for name, si in excel_info.items():
        print(f"  [{name}] {si['nrow']}行 x {si['ncol']}列")

    for s in sheets:
        df = client.read_excel(sheet=s, head=5)
        print(f"\n--- {s} (前5行) ---")
        print(df)
