from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path
from typing import Iterable
from urllib.parse import urlencode
from urllib.request import Request, urlopen

BASE_URL = "https://data.stats.gov.cn/easyquery.htm"
DEFAULT_HEADERS = {
    "User-Agent": "Mozilla/5.0",
}


class NBSEasyQueryClient:
    def __init__(self, timeout: int = 30) -> None:
        self.timeout = timeout

    def _get_json(self, params: dict) -> dict:
        query = urlencode(params)
        request = Request(f"{BASE_URL}?{query}", headers=DEFAULT_HEADERS)
        with urlopen(request, timeout=self.timeout) as response:
            return json.loads(response.read().decode("utf-8", errors="ignore"))

    def query_indicator(
        self,
        indicator_code: str,
        dbcode: str = "fsnd",
        rowcode: str = "reg",
        colcode: str = "sj",
    ) -> list[dict]:
        payload = {
            "m": "QueryData",
            "dbcode": dbcode,
            "rowcode": rowcode,
            "colcode": colcode,
            "wds": "[]",
            "dfwds": json.dumps(
                [{"wdcode": "zb", "valuecode": indicator_code}],
                ensure_ascii=False,
            ),
            "k1": "1",
            "h": "1",
        }
        data = self._get_json(payload)
        if data.get("returncode") != 200:
            raise RuntimeError(f"Query failed for {indicator_code}: {data}")

        result = data["returndata"]
        dimension_maps = self._build_dimension_maps(result.get("wdnodes", []))
        rows = []

        for node in result.get("datanodes", []):
            wds = {item["wdcode"]: item["valuecode"] for item in node.get("wds", [])}
            metric_code = wds.get("zb", indicator_code)
            region_code = wds.get("reg")
            year_code = wds.get("sj")
            point = node.get("data", {})

            rows.append(
                {
                    "requested_code": indicator_code,
                    "indicator_code": metric_code,
                    "indicator_name": dimension_maps["zb"].get(metric_code, metric_code),
                    "region_code": region_code,
                    "region_name": dimension_maps["reg"].get(region_code, region_code),
                    "year": int(year_code) if year_code else None,
                    "value": point.get("data"),
                    "display_value": point.get("strdata"),
                    "has_data": bool(point.get("hasdata")),
                }
            )

        return sorted(
            rows,
            key=lambda item: (
                item["indicator_code"],
                item["region_code"] or "",
                item["year"] or 0,
            ),
        )

    @staticmethod
    def _build_dimension_maps(wdnodes: list[dict]) -> dict[str, dict[str, str]]:
        dimension_maps: dict[str, dict[str, str]] = {"zb": {}, "reg": {}, "sj": {}}
        for dimension in wdnodes:
            code = dimension.get("wdcode")
            if code not in dimension_maps:
                continue
            for node in dimension.get("nodes", []):
                dimension_maps[code][node["code"]] = node.get("cname") or node.get("name")
        return dimension_maps


def fetch_many(
    indicator_codes: Iterable[str],
    output_dir: Path,
    min_year: int | None = None,
    max_year: int | None = None,
    drop_missing: bool = True,
) -> list[Path]:
    client = NBSEasyQueryClient()
    output_dir.mkdir(parents=True, exist_ok=True)
    saved_files: list[Path] = []

    for indicator_code in indicator_codes:
        rows = client.query_indicator(indicator_code)
        if min_year is not None:
            rows = [row for row in rows if row["year"] is not None and row["year"] >= min_year]
        if max_year is not None:
            rows = [row for row in rows if row["year"] is not None and row["year"] <= max_year]
        if drop_missing:
            rows = [row for row in rows if row["has_data"]]

        output_path = output_dir / f"{indicator_code}.csv"
        write_rows(output_path, rows)
        saved_files.append(output_path)

    return saved_files


def write_rows(path: Path, rows: list[dict]) -> None:
    fieldnames = [
        "requested_code",
        "indicator_code",
        "indicator_name",
        "region_code",
        "region_name",
        "year",
        "value",
        "display_value",
        "has_data",
    ]
    with path.open("w", newline="", encoding="utf-8-sig") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Fetch province-year indicators from NBS EasyQuery."
    )
    parser.add_argument("indicator_codes", nargs="+", help="Indicator codes to query.")
    parser.add_argument(
        "--output-dir",
        default="supply_chain_resilience/data/public_indicators",
        help="Directory for csv exports.",
    )
    parser.add_argument("--min-year", type=int, default=2016)
    parser.add_argument("--max-year", type=int, default=2024)
    parser.add_argument(
        "--keep-missing",
        action="store_true",
        help="Keep rows without released data.",
    )
    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()
    output_dir = Path(args.output_dir)
    saved_files = fetch_many(
        indicator_codes=args.indicator_codes,
        output_dir=output_dir,
        min_year=args.min_year,
        max_year=args.max_year,
        drop_missing=not args.keep_missing,
    )
    for path in saved_files:
        print(path)


if __name__ == "__main__":
    main()
