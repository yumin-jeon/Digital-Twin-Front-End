# Digital Twin - Swath Mode (리펙토링 구조 + F5 Swath View)

이 폴더는 `html_refactoring/` 기반에 **Swath View 모드(F5)** 를 추가한 확장 버전입니다.

## Swath View 주요 기능

- **고정 파라미터**: Pixel Size = 5 μm (`CAMERA_PIXEL_SIZE` in `js/config.js`)
- **가변 파라미터**:
  - `SWATH_GSD` = 10.0 m/px (임의값, 수정 가능)
  - `SWATH_N_PIX` = 3000 px (임의값, 수정 가능)
- **Swath 계산**: `Swath = SWATH_GSD × SWATH_N_PIX` = 30,000 m = 30 km
- **FOV 계산**: 현재 고도에서 전체 Swath가 화면 수직 방향에 맞도록 자동 조정
  - `vfov = 2 × atan(Swath / (2 × altitude))`
- **키 바인딩**: `F5` 로 진입 (내부 모드 번호 = 4)
- **UI 오버레이**: GSD, N_pix, Pixel Size, Swath, Coverage, Altitude, FOV 실시간 표시 + 지상 거리 스케일 바 + 코너 브래킷 크로스헤어

파라미터 변경은 `js/config.js`의 `SWATH_GSD`, `SWATH_N_PIX` 값만 바꾸면 됩니다.

---



## 1. 리펙토링 배경

### 기존 문제점

기존에는 3개의 독립된 HTML 파일에 CSS, JavaScript가 모두 인라인으로 포함되어 있었습니다.

```
기존 구조 (main/)
├── cesium_improved-code73 baseline.html          (818줄)  ← 초기 프로토타입
├── cesium_improved-code73_baseline_Jeju.html      (1,451줄) ← 주력 버전
└── cesium_improved-code73_baseline_Jeju_F4.html   (1,619줄) ← 최신 버전 (GSD 추가)
```

**주요 문제:**
- Jeju.html과 Jeju_F4.html 사이에 **~1,400줄의 코드가 완전히 중복**
- 하나의 파일이 1,600줄이 넘어 **특정 기능을 찾기 어려움**
- 버그 수정 시 **여러 파일을 동시에 수정**해야 하는 위험
- CSS, HTML, JS가 하나의 파일에 섞여 있어 **역할 구분이 불명확**

### 해결 방향

- 3개 HTML을 **1개로 통합** (최신 완전판 Jeju_F4 기준)
- CSS/JS를 **역할별 외부 파일로 분리**
- 기존 코드의 `// ========== 섹션 ==========` 주석 경계를 그대로 파일 단위로 나눔

---

## 2. 새로운 폴더 구조

```
main/refactoring/
│
├── index.html              ← HTML 구조 (UI 레이아웃만)
│
├── css/
│   └── style.css           ← 전체 스타일시트
│
└── js/
    ├── config.js           ← 설정값 · 상수
    ├── utils.js            ← 유틸리티 함수
    ├── state.js            ← 전역 상태 변수
    ├── cesium-init.js      ← Cesium 초기화
    ├── indicators.js       ← 방향 인디케이터 (Velocity, Nadir, North, South)
    ├── camera.js           ← 카메라 모드 (Tracking, Satellite, GSD)
    ├── telemetry.js        ← 텔레메트리 패널 UI
    ├── charts.js           ← Chart.js 실시간 그래프
    ├── controls.js         ← 키보드 · WASD 패드 · 모드 전환
    ├── websocket.js        ← WebSocket 연결 관리
    └── app.js              ← 앱 진입점 (initialize)
```

---

## 3. 각 파일의 역할

### index.html (250줄)
**HTML 구조만** 담당합니다. JavaScript 로직이나 CSS 스타일은 포함하지 않습니다.

포함된 UI 영역:
| 위치 | 요소 | 설명 |
|------|------|------|
| 전체 | `#cesiumContainer` | Cesium 3D 뷰포트 |
| 좌상단 | `.mode-panel` | 제어 모드 선택 패널 (0~7) |
| 우상단 | `.status-panel` | 텔레메트리 + 실시간 그래프 |
| 좌하단 | `.controls-info` | 카메라 모드 안내 (F1~F4) |
| 하단 중앙 | `.attitude-control-panel` | WASD 자세 제어 패드 (모드 4에서만 표시) |
| 우하단 | `.legend` | 방향 인디케이터 범례 |
| 하단 중앙 | `.gsd-overlay`, `.gsd-crosshair` | GSD 뷰 오버레이 (F4에서만 표시) |

스크립트 로딩 순서 (`index.html` 하단):
```html
<script src="js/config.js"></script>      <!-- 1. 상수 정의 -->
<script src="js/utils.js"></script>       <!-- 2. 유틸리티 함수 -->
<script src="js/state.js"></script>       <!-- 3. 전역 변수 선언 -->
<script src="js/cesium-init.js"></script> <!-- 4. Cesium 초기화 -->
<script src="js/indicators.js"></script>  <!-- 5. 방향 인디케이터 -->
<script src="js/camera.js"></script>      <!-- 6. 카메라 모드 -->
<script src="js/telemetry.js"></script>   <!-- 7. 텔레메트리 UI -->
<script src="js/charts.js"></script>      <!-- 8. 실시간 그래프 -->
<script src="js/controls.js"></script>    <!-- 9. 입력 제어 -->
<script src="js/websocket.js"></script>   <!-- 10. WebSocket -->
<script src="js/app.js"></script>         <!-- 11. 앱 시작 -->
```

> **주의:** 스크립트 로딩 순서가 중요합니다. 각 파일은 이전 파일에서 정의된 변수/함수를 참조할 수 있으므로, 위 순서를 변경하면 오류가 발생할 수 있습니다.

---

### css/style.css (532줄)
모든 UI 컴포넌트의 스타일을 담당합니다. 내부 섹션 구분:

```
Global Font Settings          ← 기본 폰트, body 스타일
Telemetry Panel               ← 우상단 텔레메트리 패널
Mode Panel                    ← 좌상단 모드 선택 패널
Controls Info                 ← 좌하단 카메라 안내
Legend                        ← 방향 인디케이터 범례
Telemetry Sections            ← 텔레메트리 세부 항목
GSD View Overlay              ← GSD 뷰 전용 UI
Real-time Graph Styles        ← Chart.js 그래프 카드
Attitude Control Panel        ← WASD 패드 / Roll 버튼
```

---

### js/config.js (36줄)
앱 전체에서 사용하는 **상수와 설정값**을 한 곳에 모았습니다.

| 상수 | 값 | 용도 |
|------|----|------|
| `CESIUM_ION_TOKEN` | JWT 문자열 | Cesium Ion 인증 |
| `BODY_OFFSET` | `(-30, 30, 0)` | 위성 모델 중심 보정 |
| `CAMERA_GSD` | `0.3` m/px | GSD 뷰 해상도 |
| `MODE_NAMES` | 배열 [8개] | 제어 모드 이름 |
| `MAX_DATA_POINTS` | `100` | 그래프에 표시할 최대 데이터 수 |
| `KEY_TO_BUTTON_ID` | 객체 | 키보드 → UI 버튼 매핑 |
| `WEBSOCKET_URL` | `ws://localhost:8765` | WebSocket 서버 주소 |
| `SATELLITE_MODEL_URI` | `../VLEO_Satellite.glb` | 위성 3D 모델 경로 |

**설정을 바꿔야 할 때는 이 파일만 수정하면 됩니다.**

---

### js/utils.js (36줄)
다른 모듈에서 공통으로 사용하는 **순수 유틸리티 함수**입니다.

| 함수 | 기능 |
|------|------|
| `formatNumber(value, decimals)` | 숫자를 고정 소수점 문자열로 변환 |
| `radToDeg(rad)` | 라디안 → 도 변환 |
| `ecefToLla(x, y, z)` | ECEF 좌표 → 위도/경도/고도 변환 |
| `getBodyAxes(quat)` | 쿼터니언에서 위성 Body 축 (x, y, z) 추출 |
| `applyBodyOffset(pos, quat)` | 위성 위치에 Body 프레임 오프셋 적용 |

---

### js/state.js (62줄)
앱 전체에서 공유하는 **변경 가능한 상태 변수**를 선언합니다.

주요 상태 그룹:
- **Cesium 엔티티**: `viewer`, `satellite`, `orbitEntity`, 축(x/y/z)
- **보간 속성**: `positionProperty`, `orientationProperty`, `velocityProperty`
- **방향 인디케이터**: `orbitalVelocityVector`, `nadirVector` 등
- **인디케이터 캐시**: `_p`, `_velEnd`, `_nadirEnd` 등 (매 프레임 갱신)
- **WebSocket**: `socket`, `isConnected`, `isFirstMessage`
- **제어 모드**: `currentControlMode`, `backendControlMode`
- **그래프 데이터**: `graphData`, `charts`

---

### js/cesium-init.js (107줄)
Cesium 뷰어와 3D 오브젝트를 **초기 생성**합니다.

| 함수 | 기능 |
|------|------|
| `initCesium()` | Cesium Viewer 생성, 위성 모델 로드, Body 축·궤도 궤적·방향 인디케이터 엔티티 생성 |
| `recordOrbitPath()` | 100ms 간격으로 현재 위성 위치를 궤도 궤적 배열에 추가 (최대 300점) |

---

### js/indicators.js (125줄)
Velocity, Nadir, North, South **방향 인디케이터 벡터 계산**을 담당합니다.

| 함수 | 호출 시점 |
|------|----------|
| `updateDirectionIndicators(position, quat)` | Tracking 모드에서 호출 |
| `updateDirectionIndicatorsForSatelliteView(...)` | Satellite View 모드에서 호출 (카메라 전방에 인디케이터 배치) |
| `setIndicatorsVisible(flag)` | 카메라 모드 전환 시 인디케이터 표시/숨김 |

---

### js/camera.js (152줄)
4가지 **카메라 모드**를 관리합니다.

| 함수 | 기능 |
|------|------|
| `switchCameraMode(mode)` | 카메라 모드 전환 (0~3). 각 모드에 맞게 UI, 엔티티 표시, 카메라 설정 변경 |
| `setupSatelliteView()` | Satellite View 카메라 리스너 등록 (매 프레임 위성 시점으로 카메라 갱신) |
| `setupGSDView()` | GSD View 카메라 리스너 등록 (1px = 0.3m 해상도로 FOV 계산) |
| `updateGSDScalebar(canvasWidth)` | GSD 뷰의 스케일바 길이를 화면 크기에 맞게 갱신 |

카메라 모드 정리:
| 모드 | 키 | 이름 | 설명 |
|------|----|------|------|
| 0 | F1 | Tracking | 위성 추적, 줌 가능, 60° FOV |
| 1 | F2 | Satellite (Wide) | 위성 시점, 0.7° FOV |
| 2 | F3 | Satellite (Zoom) | 위성 시점, 15° FOV |
| 3 | F4 | GSD View | 지상 해상도 뷰, 1px = 0.3m |

---

### js/telemetry.js (99줄)
우상단 **텔레메트리 패널 UI**를 갱신합니다.

| 함수 | 기능 |
|------|------|
| `toggleTelemetryDetails()` | 텔레메트리 패널 접기/펼치기 |
| `updateTelemetryDisplay(data)` | WebSocket으로 수신한 데이터를 파싱하여 UI에 반영. 위치(LLA), 포인팅 에러, 휠 속도, 타겟 정보 표시 |

---

### js/charts.js (120줄)
Chart.js를 사용한 **실시간 그래프 6개** (Angular Rate 3개 + Attitude 3개)를 관리합니다.

| 함수 | 기능 |
|------|------|
| `initCharts()` | 6개의 Chart.js 인스턴스 생성 (CMD: 파란색, ACT: 빨간색) |
| `updateCharts(data)` | 텔레메트리 데이터에서 각속도/오일러 값 추출 → 그래프 데이터 추가 → 차트 갱신 |

---

### js/controls.js (137줄)
모든 **사용자 입력 처리**를 담당합니다. 세 가지 영역으로 구분됩니다.

**1. 제어 모드 UI**
| 함수 | 기능 |
|------|------|
| `toggleModePanel()` | 좌상단 모드 패널 접기/펼치기 |
| `setControlMode(mode)` | 제어 모드 변경 → UI 갱신 + WebSocket 전송 |
| `updateModeButtonsUI(mode)` | 모드 버튼 활성화 상태 갱신 |
| `updateBackendModeDisplay(mode)` | MATLAB에서 수신한 모드를 UI에 반영 |

**2. WASD 자세 제어 패드** (모드 4: Interactive에서만 활성)
| 함수 | 기능 |
|------|------|
| `sendAttitudeCommand(command)` | 자세 명령 WebSocket 전송 |
| `setupAttitudeControlButtons()` | SVG 패드 및 Roll 버튼에 터치/마우스 이벤트 바인딩 |
| `updateAttitudeControlPanelVisibility()` | 모드 4일 때만 패드 표시 |

**3. 키보드 입력**
| 함수 | 기능 |
|------|------|
| `setupKeyboardControls()` | F1~F4 → 카메라 전환, 0~7 → 모드 전환, WASD/QE/Space → 자세 명령 |

---

### js/websocket.js (59줄)
Python relay(`websocket_relay_Jeju.py`)와의 **WebSocket 통신**을 관리합니다.

| 함수 | 기능 |
|------|------|
| `connectWebSocket()` | WebSocket 연결. 수신 데이터를 `positionProperty`/`orientationProperty`에 샘플 추가. 최초 메시지 수신 시 시계 동기화 및 UI 초기화 수행. 연결 끊김 시 3초 후 재접속 |

---

### js/app.js (14줄)
앱의 **진입점**입니다. `DOMContentLoaded` 이벤트에서 모든 모듈을 초기화합니다.

```
initialize()
 ├── initCesium()                    ← cesium-init.js
 ├── initCharts()                    ← charts.js
 ├── setupKeyboardControls()         ← controls.js
 ├── setupAttitudeControlButtons()   ← controls.js
 ├── connectWebSocket()              ← websocket.js
 ├── updateAttitudeControlPanelVisibility() ← controls.js
 └── updateModeButtonsUI()           ← controls.js
```

---

## 4. 데이터 흐름

```
MATLAB (main_InteractiveSatControlvJeju.m)
  │  telemetry_out.json 기록
  ▼
Python WebSocket Relay (websocket_relay_Jeju.py, port 8765)
  │  WebSocket으로 JSON 전송
  ▼
websocket.js ─── onmessage
  │  positionProperty/orientationProperty에 샘플 추가
  ├──► telemetry.js ─── updateTelemetryDisplay()
  │       └──► charts.js ─── updateCharts()
  │
  └──► Cesium 보간 엔진 (매 프레임)
          ├──► cesium-init.js ─── 축/궤도 CallbackProperty
          ├──► indicators.js ─── 방향 인디케이터 갱신
          └──► camera.js ─── 카메라 위치/방향 갱신

사용자 입력 (키보드 / WASD 패드)
  │
  ▼
controls.js
  ├──► camera.js ─── switchCameraMode() [F1~F4]
  ├──► controls.js ─── setControlMode() [0~7]
  └──► websocket.js ─── socket.send() [WASD/QE/Space 명령]
          │
          ▼
      Python Relay → command_in.json → MATLAB
```

---

## 5. 실행 방법

```bash
# 1. MATLAB (기존과 동일)
setup_path()
cd main
main_InteractiveSatControlvJeju

# 2. Python WebSocket relay (기존과 동일)
cd main
pip install -r requirements.txt
python websocket_relay_Jeju.py

# 3. HTTP 서버 실행 후 브라우저에서 접속
cd main
python -m http.server 8000
```

브라우저에서 `http://localhost:8000/refactoring/index.html` 접속

---

## 6. 수정 가이드

### "WebSocket 포트를 바꾸고 싶다"
→ `js/config.js`의 `WEBSOCKET_URL` 수정

### "위성 모델을 교체하고 싶다"
→ `js/config.js`의 `SATELLITE_MODEL_URI` 경로 수정

### "새로운 카메라 모드를 추가하고 싶다"
→ `js/camera.js`의 `switchCameraMode()`에 분기 추가 + `js/controls.js`에 키 바인딩 추가

### "텔레메트리에 새로운 항목을 표시하고 싶다"
→ `js/telemetry.js`의 `updateTelemetryDisplay()`에 HTML 블록 추가

### "그래프를 추가하고 싶다"
→ `index.html`에 `<canvas>` 추가 + `js/charts.js`에 차트 ID 등록

### "새로운 제어 모드를 추가하고 싶다"
→ `js/config.js`의 `MODE_NAMES` 배열 확장 + `index.html`에 버튼 추가 + `js/controls.js`에 키 바인딩 추가

### "GSD 해상도를 변경하고 싶다"
→ `js/config.js`의 `CAMERA_GSD` 값 수정

---

## 7. 기존 파일과의 대응표

기존 단일 HTML의 코드 섹션이 어떤 파일로 분리되었는지 보여줍니다.

| 기존 HTML 섹션 | 리펙토링 파일 |
|----------------|---------------|
| `<style>...</style>` | `css/style.css` |
| `<body>` HTML 구조 | `index.html` |
| `// Global Variables` | `js/state.js` |
| `// Utility Functions` | `js/utils.js` |
| `// Control Mode Functions` | `js/controls.js` |
| `// Cesium Initialization` | `js/cesium-init.js` |
| `// WebSocket` | `js/websocket.js` |
| `// Direction Indicators & View` | `js/indicators.js` |
| `// GSD View` + camera switching | `js/camera.js` |
| `// Telemetry UI` | `js/telemetry.js` |
| `// Keyboard Controls` | `js/controls.js` |
| `// Chart.js` | `js/charts.js` |
| `initialize()` + `DOMContentLoaded` | `js/app.js` |
| 하드코딩된 상수 (토큰, URL 등) | `js/config.js` |
