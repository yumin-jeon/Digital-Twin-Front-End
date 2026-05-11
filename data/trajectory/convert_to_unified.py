"""
convert_to_unified.py
=====================
ADS-B / AIS / Projectile 데이터를 통일 JSON 포맷으로 변환.

출력 위치: data/trajectory/unified/{adsb,ais,projectile}/*.json

통일 포맷 (공통 헤더):
  id            : 식별자 (ICAO hex | MMSI | 기체명)
  source        : "adsb" | "ais" | "projectile"
  type          : 기종/선종 코드
  desc          : 사람이 읽을 수 있는 설명
  callsign      : 콜사인/등록번호
  timestamp     : Unix epoch (adsb) | null (ais/projectile)
  time_reference: "unix_offset" | "unix_absolute" | "sim_elapsed"
  nav_status    : AIS 항행 상태 (ais 전용, 0=항행 1=정박 5=계류)
  dimensions    : AIS 선체 치수 {a,b,c,d} m (ais 전용, optional)
  trace_columns : 컬럼 설명 목록
  trace         : [[...], ...] 실제 데이터

trace 컬럼:
  ADS-B       : [time, lat, lon, alt_m, speed_kn, heading_deg, alt_geom_m, vertical_rate_fpm]
  AIS         : [time, lat, lon, alt_m, speed_kn, heading_deg]
  Projectile  : [time, lat, lon, alt_m, vn_mps, ve_mps, vd_mps, vmag_mps]

변환 규칙:
  ADS-B  alt_baro feet→m,  alt_geom feet→m (null 허용)
  AIS    trace를 0~36000s 시뮬 창으로 crop, speed=0은 0.0 보존
  Nuri   lat/lon rad→deg, 70000 포인트 전부 유지
"""

import csv
import json
import math
import os
from datetime import datetime, timezone

# ── 경로 ──────────────────────────────────────────────────────────────────────
SCRIPT_DIR  = os.path.dirname(os.path.abspath(__file__))
ADSB_DIR    = os.path.join(SCRIPT_DIR, "raw", "adsb")
AIS_FILE    = os.path.join(SCRIPT_DIR, "raw", "ais", "korea_ships.csv")
PROJ_FILE   = os.path.join(SCRIPT_DIR, "raw", "projectile", "Nuri.json")
OUT_BASE    = os.path.join(SCRIPT_DIR, "unified")

SIM_WINDOW  = 36_000   # 시뮬레이션 구간 (초)

# ── AIS 상위 10척 (UserID 기준) ───────────────────────────────────────────────
# 선정 기준: 0~36000s 시뮬레이션 구간 내 누적이동거리 + 순이동거리 + 커버율 + 샘플수 종합
# 순위  MMSI  simPts  커버율   순이동km  누적이동km  비고
#   1   1027    16    72.9%    28.47     35.29   이동거리 최상위
#   2    656    16    72.5%    25.66     36.70   누적이동 최대
#   3   1381    14    60.6%    22.64     33.53   이동거리 우수
#   4    502    16    70.2%    24.50     29.12   이동거리 우수
#   5    926    21    95.7%    19.27     27.32   커버율 최상위
#   6    215    21    96.6%    18.07     24.78   커버율 최상위
#   7    772    16    71.0%    21.43     24.74   이동/커버 균형
#   8    721    18    81.7%    15.20     26.21   이동/커버 균형
#   9    436    19    87.6%    15.65     24.93   이동/커버 균형
#  10    634    16    71.9%    21.04     23.98   이동/커버 균형
AIS_TOP10 = {"1027", "656", "1381", "502", "926", "215", "772", "721", "436", "634"}

TRACE_COLS_ADSB = [
    {"index": 0, "name": "time",              "unit": "s"},
    {"index": 1, "name": "lat",               "unit": "deg"},
    {"index": 2, "name": "lon",               "unit": "deg"},
    {"index": 3, "name": "alt",               "unit": "m"},
    {"index": 4, "name": "speed",             "unit": "knots"},
    {"index": 5, "name": "heading",           "unit": "deg"},
    {"index": 6, "name": "alt_geom",          "unit": "m"},
    {"index": 7, "name": "vertical_rate",     "unit": "fpm"},
]
TRACE_COLS_AIS = [
    {"index": 0, "name": "time",    "unit": "s"},
    {"index": 1, "name": "lat",     "unit": "deg"},
    {"index": 2, "name": "lon",     "unit": "deg"},
    {"index": 3, "name": "alt",     "unit": "m"},
    {"index": 4, "name": "speed",   "unit": "knots"},
    {"index": 5, "name": "heading", "unit": "deg"},
]
TRACE_COLS_PROJ = [
    {"index": 0, "name": "time",   "unit": "s"},
    {"index": 1, "name": "lat",    "unit": "deg"},
    {"index": 2, "name": "lon",    "unit": "deg"},
    {"index": 3, "name": "alt",    "unit": "m"},
    {"index": 4, "name": "vn",     "unit": "m/s"},
    {"index": 5, "name": "ve",     "unit": "m/s"},
    {"index": 6, "name": "vd",     "unit": "m/s"},
    {"index": 7, "name": "vmag",   "unit": "m/s"},
]

# ── 유틸 ──────────────────────────────────────────────────────────────────────
def _parse_ais_ts(ts_str: str) -> float:
    ts_str = ts_str.strip()
    for tz in ("+00:00", "-00:00", "Z"):
        if ts_str.endswith(tz):
            ts_str = ts_str[: -len(tz)]
            break
    dot = ts_str.find(".")
    if dot != -1:
        ts_str = ts_str[: dot + 7]
    try:
        dt = datetime.strptime(ts_str, "%Y-%m-%d %H:%M:%S.%f")
    except ValueError:
        dt = datetime.strptime(ts_str, "%Y-%m-%d %H:%M:%S")
    return dt.replace(tzinfo=timezone.utc).timestamp()

def _write(path: str, obj: dict) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False, indent=2)

# ── ADS-B 변환 ────────────────────────────────────────────────────────────────
def convert_adsb() -> int:
    out_dir = os.path.join(OUT_BASE, "adsb")
    count = 0
    for fname in sorted(os.listdir(ADSB_DIR)):
        if not fname.endswith(".json"):
            continue
        with open(os.path.join(ADSB_DIR, fname), encoding="utf-8") as f:
            raw = json.load(f)

        trace = []
        for node in raw.get("trace", []):
            if len(node) < 3:
                continue

            # [3] alt_baro (feet)
            alt_raw = node[3] if len(node) > 3 else None
            if not isinstance(alt_raw, (int, float)):
                alt_raw = None
            alt_m = round(alt_raw * 0.3048, 1) if alt_raw is not None else None

            # [4] speed (knots), [5] track/heading (deg)
            speed   = round(float(node[4]), 2) if len(node) > 4 and isinstance(node[4], (int, float)) else None
            heading = round(float(node[5]), 2) if len(node) > 5 and isinstance(node[5], (int, float)) else None

            # [7] vertical_rate (fpm) — [8]이 dict이면 [7]은 숫자
            vert_raw = node[7] if len(node) > 7 else None
            vertical_rate = round(float(vert_raw), 1) if isinstance(vert_raw, (int, float)) else None

            # [10] alt_geom (feet) — 상세 객체가 있는 행에만 존재
            alt_geom_raw = node[10] if len(node) > 10 else None
            alt_geom_m = round(float(alt_geom_raw) * 0.3048, 1) if isinstance(alt_geom_raw, (int, float)) else None

            trace.append([
                round(float(node[0]), 3),   # time offset (s)
                round(float(node[1]), 6),   # lat (deg)
                round(float(node[2]), 6),   # lon (deg)
                alt_m,                      # alt_baro (m)
                speed,                      # speed (knots)
                heading,                    # heading/track (deg)
                alt_geom_m,                 # alt_geom (m), null 허용
                vertical_rate,              # vertical_rate (fpm), null 허용
            ])

        out = {
            "id":             raw.get("icao", fname.replace(".json", "")),
            "source":         "adsb",
            "type":           raw.get("t"),
            "desc":           raw.get("desc"),
            "callsign":       raw.get("r"),
            "timestamp":      raw.get("timestamp"),
            "time_reference": "unix_offset",
            "trace_columns":  TRACE_COLS_ADSB,
            "trace":          trace,
        }
        _write(os.path.join(out_dir, fname), out)
        print(f"  [adsb] {fname}: {len(trace)} pts")
        count += 1
    return count

# ── AIS 변환 ──────────────────────────────────────────────────────────────────
def _ais_t_start(ais_file: str) -> float:
    """전체 AIS CSV에서 최소 timestamp → t_start_ais 계산."""
    min_ts = float("inf")
    with open(ais_file, encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            try:
                ts = _parse_ais_ts(row["timestamp"])
                if ts < min_ts:
                    min_ts = ts
            except Exception:
                continue
    return min_ts

def convert_ais() -> int:
    out_dir = os.path.join(OUT_BASE, "ais")
    t_start = _ais_t_start(AIS_FILE)
    print(f"  [ais] t_start: {datetime.fromtimestamp(t_start, tz=timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}")

    ships: dict = {}
    with open(AIS_FILE, encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            try:
                uid = str(row.get("UserID", "")).strip()
                if uid not in AIS_TOP10:
                    continue

                lat = float(row["Latitude"])
                lon = float(row["Longitude"])
                ts  = _parse_ais_ts(row["timestamp"])

                # 시뮬레이션 창(0~36000s) 밖 포인트 제외
                sim_elapsed = ts - t_start
                if not (0 <= sim_elapsed <= SIM_WINDOW):
                    continue

                # speed: 빈 문자열만 None, 0은 0.0으로 보존
                speed_raw = row.get("speed", "").strip()
                speed = float(speed_raw) if speed_raw != "" else None

                cog_raw = row.get("Cog", "").strip()
                cog = float(cog_raw) if cog_raw != "" else None

                hdg_raw = row.get("TrueHeading", "").strip()
                try:
                    hdg = float(hdg_raw)
                    # 511 = 미사용 값, Cog로 대체
                    heading = hdg if hdg != 511.0 else cog
                except (ValueError, TypeError):
                    heading = cog

                if uid not in ships:
                    # 선체 치수 (DimensionA/B/C/D) — optional
                    def _dim(key):
                        v = row.get(key, "").strip()
                        try:
                            f = float(v)
                            return f if f > 0 else None
                        except (ValueError, TypeError):
                            return None

                    ships[uid] = {
                        "type":       row.get("ShipType", ""),
                        "desc":       row.get("ShipName") or row.get("Name") or "",
                        "callsign":   row.get("CallSign", ""),
                        "nav_status": row.get("NavigationalStatus", ""),
                        "dimensions": {
                            "a": _dim("DimensionA"),
                            "b": _dim("DimensionB"),
                            "c": _dim("DimensionC"),
                            "d": _dim("DimensionD"),
                        },
                        "trace": [],
                    }
                ships[uid]["trace"].append([
                    round(ts, 3),
                    round(lat, 6),
                    round(lon, 6),
                    0.0,
                    round(speed, 2) if speed is not None else None,
                    round(heading, 2) if heading is not None else None,
                ])
            except Exception:
                continue

    count = 0
    for uid, data in ships.items():
        data["trace"].sort(key=lambda r: r[0])
        out = {
            "id":             uid,
            "source":         "ais",
            "type":           data["type"],
            "desc":           data["desc"],
            "callsign":       data["callsign"],
            "nav_status":     data["nav_status"],
            "dimensions":     data["dimensions"],
            "timestamp":      None,
            "time_reference": "unix_absolute",
            "trace_columns":  TRACE_COLS_AIS,
            "trace":          data["trace"],
        }
        _write(os.path.join(out_dir, f"{uid}.json"), out)
        count += 1

    print(f"  [ais] {count}척 변환 완료")
    return count

# ── Projectile 변환 ────────────────────────────────────────────────────────────
def convert_projectile() -> int:
    out_dir = os.path.join(OUT_BASE, "projectile")
    with open(PROJ_FILE, encoding="utf-8") as f:
        raw = json.load(f)

    trace = []
    for row in raw.get("trace", []):
        if len(row) < 8:
            continue
        trace.append([
            round(row[0], 4),
            round(math.degrees(row[1]), 6),   # lat rad → deg
            round(math.degrees(row[2]), 6),   # lon rad → deg
            round(row[3], 3),                 # alt (m)
            round(row[4], 6),                 # vn (m/s)
            round(row[5], 6),                 # ve (m/s)
            round(row[6], 6),                 # vd (m/s)
            round(row[7], 6),                 # vmag (m/s)
        ])

    fname = os.path.basename(PROJ_FILE)
    out = {
        "id":             raw.get("icao", "nuri_nominal"),
        "source":         "projectile",
        "type":           raw.get("t", "LV"),
        "desc":           raw.get("desc", ""),
        "callsign":       raw.get("r"),
        "timestamp":      None,
        "time_reference": "sim_elapsed",
        "trace_columns":  TRACE_COLS_PROJ,
        "trace":          trace,
    }
    _write(os.path.join(out_dir, fname), out)
    print(f"  [projectile] {fname}: {len(trace)} pts")
    return 1

# ── 메인 ──────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    print("=== 통일 포맷 변환 시작 ===")
    n_adsb = convert_adsb()
    n_ais  = convert_ais()
    n_proj = convert_projectile()
    print(f"\n완료: ADS-B {n_adsb}개 / AIS {n_ais}척 / Projectile {n_proj}개")
    print(f"출력 위치: {OUT_BASE}")
