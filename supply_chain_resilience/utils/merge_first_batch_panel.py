from __future__ import annotations

import csv
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class PanelKey:
    region_code: str
    region_name: str
    year: int


def read_indicator_long(path: Path) -> list[dict]:
    with path.open('r', encoding='utf-8-sig', newline='') as handle:
        return list(csv.DictReader(handle))


def build_panel(a060101_rows: list[dict], a060201_rows: list[dict], a0g0e_rows: list[dict]) -> dict[PanelKey, dict]:
    panel: dict[PanelKey, dict] = {}

    def upsert(rows: list[dict], value_field: str, indicator_code_field: str = 'indicator_code') -> None:
        for row in rows:
            if row.get('has_data') not in ('True', 'true', '1', True):
                continue
            region_code = row.get('region_code')
            region_name = row.get('region_name')
            year_raw = row.get('year')
            if not region_code or not region_name or not year_raw:
                continue
            key = PanelKey(region_code=region_code, region_name=region_name, year=int(year_raw))
            record = panel.setdefault(key, {'region_code': key.region_code, 'region_name': key.region_name, 'year': key.year})
            record[value_field] = row.get('value')
            record[f'{value_field}__source_code'] = row.get(indicator_code_field)

    upsert(a060101_rows, 'A060101_value')
    upsert(a060201_rows, 'A060201_value')
    upsert(a0g0e_rows, 'A0G0E01_value')  # leaf code in NBS is A0G0E01

    return panel


def write_panel_csv(panel: dict[PanelKey, dict], output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = [
        'region_code',
        'region_name',
        'year',
        'A060101_value',
        'A060201_value',
        'A0G0E01_value',
        'A060101_value__source_code',
        'A060201_value__source_code',
        'A0G0E01_value__source_code',
    ]

    rows = [panel[key] for key in sorted(panel.keys(), key=lambda k: (k.region_code, k.year))]
    with output_path.open('w', encoding='utf-8-sig', newline='') as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    base = Path('supply_chain_resilience/data/public_indicators')
    panel = build_panel(
        read_indicator_long(base / 'A060101.csv'),
        read_indicator_long(base / 'A060201.csv'),
        read_indicator_long(base / 'A0G0E.csv'),
    )
    out = Path('supply_chain_resilience/data/panels/first_batch_panel_2016_2024.csv')
    write_panel_csv(panel, out)
    print(out)


if __name__ == '__main__':
    main()
