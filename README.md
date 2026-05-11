# VLEO-Simulator

**Very Low Earth Orbit (VLEO) Satellite Attitude Control Simulation System**

MATLAB 기반 위성 자세 제어 시뮬레이션과 Cesium 3D 실시간 시각화를 통합한 인터랙티브 시뮬레이터입니다.

---

## 빠른 시작

```bash
# Windows: 더블클릭으로 전체 실행
run_sim2.bat            # 원본 HTML 버전
run_refactored.bat      # 리펙토링 버전
```

또는 수동 실행:
```bash
# 1. MATLAB
setup_path(); main_InteractiveSatControlvJeju

# 2. Python relay
cd main && python websocket_relay_Jeju.py

# 3. HTTP 서버 + 브라우저
cd main && python -m http.server 8000
# 원본: http://localhost:8000/cesium_improved-code73_baseline_Jeju_F4.html
# 리펙토링: http://localhost:8000/html_refactoring/index.html
```

---

## 시스템 아키텍처

```
MATLAB (dynamics engine)
  → data/telemetry_out.json
Python WebSocket Relay (port 8765)
  → WebSocket
Cesium 3D Visualization (browser)
  → WebSocket
Python Relay
  → data/command_in.json
MATLAB (reads commands)
```

---

## 문서

| 문서 | 내용 |
|------|------|
| [시스템 전체 문서](docs/README.md) | 아키텍처, 설치, 제어 모드, 통신 프로토콜, 수학 모델, 키보드 단축키, 문제 해결 |
| [프론트엔드 리펙토링 가이드](main/html_refactoring/README.md) | 리펙토링 배경, 모듈 구조, 파일별 역할, 데이터 흐름, 수정 가이드 |

---

## 주요 폴더 구조

```
├── main/
│   ├── main_InteractiveSatControlvJeju.m    # MATLAB 시뮬레이션 메인
│   ├── websocket_relay_Jeju.py              # Python WebSocket 릴레이
│   ├── cesium_improved-code73_baseline_Jeju_F4.html  # 원본 Cesium UI
│   ├── VLEO_Satellite.glb                   # 위성 3D 모델
│   ├── requirements.txt                     # Python 의존성
│   └── html_refactoring/                    # 리펙토링된 프론트엔드
│       ├── index.html
│       ├── css/style.css
│       └── js/ (11개 모듈)
├── src/                                     # MATLAB 모듈
│   ├── Dynamics/                            # 궤도·자세 동역학
│   ├── controller/                          # 자세 제어 알고리즘
│   ├── quat/                                # 쿼터니언 연산
│   └── plot/                                # MATLAB 시각화
├── data/                                    # 실시간 JSON 통신 파일
├── docs/                                    # 시스템 전체 문서
├── run_sim2.bat                             # 원본 통합 실행
└── run_refactored.bat                       # 리펙토링 통합 실행
```
