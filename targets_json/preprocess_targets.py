import pandas as pd
import json
import os
import gzip

# --- 설정 (한국 지역 확장 ROI) ---
ROI_LAT = (33.0, 40.0)
ROI_LON = (124.0, 135.0)

# 데이터 경로 설정 (시뮬레이터 프로젝트 내 경로 기준)
RAW_ADSB_DIR = r'data/targets/raw/adsb'
RAW_AIS = r'data/targets/raw/ais/Busan_anonymized.csv'

OUT_ADSB_DIR = r'data/targets/filtered/adsb'
OUT_AIS = r'data/targets/filtered/ais/korea_ships.csv'

def is_in_roi(lat, lon):
    """지정한 좌표가 한국 관심 영역(ROI) 내에 있는지 확인"""
    return ROI_LAT[0] <= lat <= ROI_LAT[1] and ROI_LON[0] <= lon <= ROI_LON[1]

def process_adsb():
    """항공기 ADS-B 트레이스 데이터를 처리 및 필터링"""
    print(f"ADS-B 데이터 정제 중 (경로: {RAW_ADSB_DIR})...")
    if not os.path.exists(RAW_ADSB_DIR):
        print("에러: ADS-B 원본 디렉토리를 찾을 수 없습니다.")
        return

    os.makedirs(OUT_ADSB_DIR, exist_ok=True)
    
    # 원본 디렉토리 내의 모든 JSON 및 JSON.GZ 파일 처리
    processed_count = 0
    for filename in os.listdir(RAW_ADSB_DIR):
        if filename.endswith(('.json', '.json.gz', '.gz')):
            path = os.path.join(RAW_ADSB_DIR, filename)
            
            try:
                # 압축 파일 여부에 따른 로드 방식 결정
                if filename.endswith('.gz'):
                    with gzip.open(path, 'rt', encoding='utf-8') as f:
                        data = json.load(f)
                else:
                    with open(path, 'r', encoding='utf-8') as f:
                        data = json.load(f)
                
                trace = data.get('trace', [])
                original_point_count = len(trace)
                
                # 개별 포인트별로 ROI 필터링 수행 (인덱스 1: 위도, 2: 경도)
                filtered_trace = [
                    node for node in trace 
                    if len(node) > 2 and is_in_roi(node[1], node[2])
                ]
                
                data['trace'] = filtered_trace
                
                # 시뮬레이션 엔진 로딩을 위해 압축을 해제한 일반 JSON으로 저장
                out_filename = filename.replace('.gz', '').replace('.json.json', '.json')
                if not out_filename.endswith('.json'):
                    out_filename += '.json'
                    
                out_path = os.path.join(OUT_ADSB_DIR, out_filename)
                with open(out_path, 'w', encoding='utf-8') as f:
                    json.dump(data, f, indent=2)
                
                print(f"  - {filename}: {original_point_count} -> {len(filtered_trace)} 포인트 보존 완료.")
                processed_count += 1
            except Exception as e:
                print(f"  - {filename} 처리 중 에러 발생: {e}")
    
    print(f"항공기 데이터 처리 완료: 총 {processed_count}개 파일")

def process_ais():
    """선박 AIS 데이터를 처리 및 필터링"""
    print(f"\n선박 AIS 데이터 정제 중 (파일: {RAW_AIS})...")
    if not os.path.exists(RAW_AIS):
        print("에러: AIS 원본 파일을 찾을 수 없습니다.")
        return

    # 대용량 데이터 처리를 위한 pandas 활용
    df = pd.read_csv(RAW_AIS)
    original_count = len(df)
    
    # 한국 지역 ROI 기준 필터링 마스크 생성
    mask = (df['Latitude'] >= ROI_LAT[0]) & (df['Latitude'] <= ROI_LAT[1]) & \
           (df['Longitude'] >= ROI_LON[0]) & (df['Longitude'] <= ROI_LON[1])
    
    df_filtered = df[mask]
    
    # 필터링된 결과 저장
    os.makedirs(os.path.dirname(OUT_AIS), exist_ok=True)
    df_filtered.to_csv(OUT_AIS, index=False)
    
    print(f"선박 데이터 처리 완료: {original_count} -> {len(df_filtered)} 레코드 저장됨.")
    print(f"저장 위치: {OUT_AIS}")

if __name__ == "__main__":
    process_adsb()
    process_ais()
    print("\n[VLEO 타겟 데이터 전처리 최종 완료]")
