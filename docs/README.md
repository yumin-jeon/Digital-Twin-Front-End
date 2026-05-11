# VLEO-Simulator

**Very Low Earth Orbit (VLEO) Satellite Attitude Control Simulation System**

MATLAB 기반 위성 자세 제어 시뮬레이션과 Cesium 3D 실시간 시각화를 통합한 인터랙티브 시뮬레이터입니다.

---

##  목차

1. [개요](#-개요)
2. [시스템 아키텍처](#-시스템-아키텍처)
3. [폴더 구조](#-폴더-구조)
4. [설치 요구사항](#-설치-요구사항)
5. [빠른 시작](#-빠른-시작)
6. [제어 모드](#-제어-모드)
7. [파일 상세 설명](#-파일-상세-설명)
8. [통신 프로토콜](#-통신-프로토콜)
9. [수학적 모델](#-수학적-모델)
10. [키보드 단축키](#-키보드-단축키)
11. [문제 해결](#-문제-해결)

---

##  개요

VLEO-Simulator는 초저궤도 위성의 자세 제어를 시뮬레이션하고 시각화하는 통합 시스템입니다.

### 주요 기능

- **실시간 6-DOF 위성 동역학 시뮬레이션**
- **J2 섭동을 포함한 궤도 전파**
- **6가지 자세 제어 모드** (수동 제어 포함)
- **3축 반작용휠(Reaction Wheel) 모델링**
- **Cesium 기반 3D 실시간 시각화**
- **WebSocket 양방향 통신**
- **인터랙티브 수동 제어** (키보드 입력)

---

##  시스템 아키텍처

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        VLEO-Simulator Architecture                      │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌──────────────────┐     JSON Files      ┌──────────────────┐          │
│  │                  │ ←───────────────────│                  │          │
│  │  MATLAB Engine   │   telemetry_out     │  Python Relay    │          │
│  │                  │ ──────────────────→ │  (WebSocket)     │          │
│  │  - Dynamics      │                     │                  │          │
│  │  - Controller    │   command_in        │  Port: 8765      │          │
│  │  - Orbit Prop.   │ ←─────────────────  │                  │          │
│  └──────────────────┘                     └────────┬─────────┘          │
│          │                                         │                    │
│          │ ode45                                   │ WebSocket          │
│          ↓                                         ↓                    │
│  ┌──────────────────┐                     ┌──────────────────┐          │
│  │  src/Dynamics/   │                     │  Cesium 3D       │          │
│  │  src/controller/ │                     │  Visualization   │          │
│  │  src/quat/       │                     │                  │          │
│  └──────────────────┘                     │  - 위성 3D 모델  │           │
│                                           │  - 궤도 경로     │           │
│                                           │  - 자세 축 표시  │           │
│                                           │  - 텔레메트리    │           │
│                                           └──────────────────┘          │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 데이터 흐름

1. **MATLAB → Python**: `telemetry_out.json` (위성 상태)
2. **Python → Cesium**: WebSocket (실시간 텔레메트리)
3. **Cesium → Python**: WebSocket (사용자 명령)
4. **Python → MATLAB**: `command_in.json` (제어 명령)

---

##  폴더 구조

```
VLEO-Simulator/
│
├── main/                          # 메인 실행 파일
│   ├── main_InteractiveSatControlv7.m    # MATLAB 메인 시뮬레이션
│   ├── quatDynClosedLoop.m               # 오프라인 분석용 스크립트
│   ├── websocket_relay04.py              # Python WebSocket 릴레이 서버
│   ├── cesium_improved-code73 baseline_7t2.html  # Cesium 3D 시각화
│   ├── s-net_antennen_entfaltet.glb      # 위성 3D 모델 (GLB)
│   └── run_sim.bat                       # Windows 일괄 실행 스크립트
│
├── src/                           # 소스 모듈
│   ├── Dynamics/                  # 동역학 & 궤도 모듈
│   │   ├── rhs_matlab.m          #   ODE 우변 (동역학 방정식)
│   │   ├── j2_perturbation.m     #   J2 섭동 가속도
│   │   ├── kepler2rv.m           #   케플러 요소 → 위치/속도
│   │   └── eci2ecef.m            #   ECI → ECEF 좌표 변환
│   │
│   ├── controller/                # 자세 제어기 모듈
│   │   ├── ctrlRwQuat.m          #   쿼터니언 피드백 PD 제어기
│   │   ├── ctrlRwOm.m            #   각속도 PD 제어기
│   │   ├── ctrlDamp.m            #   Rate Damping 제어기
│   │   └── actRW.m               #   반작용휠 액추에이터 모델
│   │
│   ├── quat/                      # 쿼터니언 연산 모듈
│   │   ├── quatMult.m            #   쿼터니언 곱셈
│   │   ├── quatInv.m             #   쿼터니언 역
│   │   ├── quatvrot.m            #   벡터 회전
│   │   ├── dcm2quat.m            #   DCM → 쿼터니언
│   │   ├── quat2dcm_sf.m         #   쿼터니언 → DCM
│   │   ├── qconj.m               #   쿼터니언 켤레
│   │   └── qnorm.m               #   쿼터니언 정규화
│   │
│   └── plot/                      # 시각화 모듈 (MATLAB)
│       ├── satellite3d.m         #   3D 위성 플롯
│       ├── plot_frame.m          #   좌표계 프레임 플롯
│       └── plot_sphere.m         #   지구 구체 플롯
│
├── data/                          # 통신 데이터 파일
│   ├── telemetry_out.json        #   MATLAB → Cesium 텔레메트리
│   └── command_in.json           #   Cesium → MATLAB 명령
│
└── docs/                          # 문서
    └── README.md                  #   프로젝트 문서
```

---

## ⚙ 설치 요구사항

### 필수 소프트웨어

| 소프트웨어 | 버전 | 용도 |
|-----------|------|------|
| **MATLAB** | R2020a+ | 시뮬레이션 엔진 |
| **Python** | 3.8+ | WebSocket 릴레이 |
| **웹 브라우저** | Chrome 권장 | Cesium 시각화 |

### Python 패키지 설치

```bash
pip install websockets watchdog
```

### MATLAB 경로 설정

MATLAB에서 `src` 폴더와 하위 폴더를 경로에 추가:

```matlab
addpath(genpath('src'));
```

---

##  빠른 시작

### 방법 1: 일괄 실행 (Windows)

```
main/run_sim.bat 더블클릭
```

### 방법 2: 수동 실행

**터미널 1 - WebSocket 릴레이:**
```bash
cd main
python websocket_relay04.py
```

**터미널 2 - HTTP 서버:**
```bash
cd main
python -m http.server 8000
```

**브라우저:**
```
http://localhost:8000/파일명.html
```

**MATLAB:**
```matlab
cd main
main_InteractiveSatControlv7
```

---

##  제어 모드

| 모드 | 이름 | 키 | 설명 |
|------|------|-----|------|
| **0** | No Control | `0` | 토크 없음, 자유 회전 |
| **1** | Rate Damping | `1` | 각속도 감쇠 |
| **2** | Inertial Pointing | `2` | ECI 고정 방향 지향 |
| **3** | Nadir Pointing | `3` | 지구 중심(Nadir) 지향 |
| **4** | Interactive | `4` | 수동 제어 (WASD+QE) |
| **5** | Momentum Bias | `5` | 모멘텀 바이어스 안정화 |

### 수동 제어 (Mode 4)

| 키 | 동작 |
|----|------|
| `W` / `S` | Pitch 증가 / 감소 |
| `A` / `D` | Yaw 좌회전 / 우회전 |
| `Q` / `E` | Roll 증가 / 감소 |
| `Space` | 회전 정지 |

### 카메라 모드

| 키 | 모드 |
|----|------|
| `F1` | 추적 모드 (Tracking) |
| `F2` | 위성 시점 (광각) |
| `F3` | 위성 시점 (줌) |

---

##  파일 상세 설명

### 메인 파일

#### `main_InteractiveSatControlv7.m`
- **역할**: 메인 시뮬레이션 루프
- **기능**:
  - 궤도 및 자세 초기화
  - ODE45 적분 (동역학)
  - 제어 모드 전환
  - JSON 파일 I/O
  - 실시간 루프 (1초 간격)

#### `websocket_relay04.py`
- **역할**: MATLAB ↔ Cesium 통신 브릿지
- **구성요소**:
  - `TelemetryManager`: JSON 파일 모니터링
  - `WebSocketServer`: 클라이언트 연결 관리
  - `HealthMonitor`: 시스템 상태 확인
- **포트**: 8765

#### `cesium_improved-code73 baseline_7t2.html`
- **역할**: 3D 시각화 UI
- **기능**:
  - 위성 3D 모델 렌더링
  - 궤도 경로 표시
  - Body 축 시각화
  - 텔레메트리 패널
  - 제어 입력 UI

### 동역학 모듈 (`src/Dynamics/`)

| 파일 | 함수 | 입력 | 출력 |
|------|------|------|------|
| `rhs_matlab.m` | ODE 우변 | 상태벡터, 토크 | 상태 미분 |
| `j2_perturbation.m` | J2 섭동 | 위치 벡터 | 가속도 |
| `kepler2rv.m` | 케플러 변환 | 궤도 요소 | r, v 벡터 |
| `eci2ecef.m` | 좌표 변환 | ECI 좌표, 시간 | ECEF 좌표 |

### 제어기 모듈 (`src/controller/`)

| 파일 | 제어 법칙 | 용도 |
|------|-----------|------|
| `ctrlRwQuat.m` | PD (쿼터니언) | Mode 2, 3 |
| `ctrlRwOm.m` | PD (각속도) | Mode 4 |
| `ctrlDamp.m` | 감쇠 제어 | Mode 1, 5 |
| `actRW.m` | 토크 포화 | 모든 모드 |

### 쿼터니언 모듈 (`src/quat/`)

| 파일 | 연산 | 수식 |
|------|------|------|
| `quatMult.m` | 곱셈 | q₁ ⊗ q₂ |
| `quatInv.m` | 역 | q⁻¹ = q* (단위 쿼터니언) |
| `quatvrot.m` | 벡터 회전 | q ⊗ v ⊗ q⁻¹ |
| `dcm2quat.m` | DCM → Quat | Shepperd 방법 |
| `quat2dcm_sf.m` | Quat → DCM | 직접 변환 |

---

##  통신 프로토콜

### Telemetry (MATLAB → Cesium)

```json
{
  "time": 1234.0,
  "simDate": "2025-01-15T12:34:56Z",
  "position_ecef": [x, y, z],
  "velocity_ecef": [vx, vy, vz],
  "quaternion": [x, y, z, w],
  "angularVelocity": [ωx, ωy, ωz],
  "ctrl_mode": 4,
  "ctrl_mode_name": "Interactive",
  "wheel_speeds_rpm": [rpm_x, rpm_y, rpm_z],
  "pointing_error_deg": 0.5
}
```

### Command (Cesium → MATLAB)

```json
{
  "command": "increase_pitch",
  "ctrl_mode": 4,
  "timestamp": "2025-01-15T12:34:57Z"
}
```

**명령 목록:**
- `increase_pitch`, `decrease_pitch`
- `yaw_left`, `yaw_right`
- `increase_roll`, `decrease_roll`
- `stop_rotation`
- `set_mode`

---

##  수학적 모델

### 상태 벡터 (16차원)

```
x = [ω_sat(1:3);     % 위성 각속도 [rad/s]
     q(4:7);         % 자세 쿼터니언 (scalar-first)
     ω_rw(8:10);     % 반작용휠 각속도 [rad/s]
     r_eci(11:13);   % ECI 위치 [km]
     v_eci(14:16)]   % ECI 속도 [km/s]
```

### 동역학 방정식

**위성 회전 동역학:**
$$\dot{\boldsymbol{\omega}}_{sat} = (\mathbf{I}_b + \mathbf{I}_{rw})^{-1} \left[ \mathbf{T}_{ext} - \mathbf{T}_{rw} - \boldsymbol{\omega} \times \left( (\mathbf{I}_b + \mathbf{I}_{rw})\boldsymbol{\omega}_{sat} + \mathbf{I}_{rw}\boldsymbol{\omega}_{rw} \right) \right]$$

**쿼터니언 운동학:**
$$\dot{\mathbf{q}} = \frac{1}{2} \boldsymbol{\Omega}(\boldsymbol{\omega}) \mathbf{q}$$

**반작용휠:**
$$\dot{\boldsymbol{\omega}}_{rw} = \mathbf{I}_{rw}^{-1} \mathbf{T}_{rw}$$

**궤도 전파 (Cowell):**
$$\ddot{\mathbf{r}} = -\frac{\mu}{|\mathbf{r}|^3}\mathbf{r} + \mathbf{a}_{J2}$$

### 제어 법칙

**쿼터니언 PD 제어기 (Mode 2, 3):**
$$\mathbf{T} = -\text{diag}(\mathbf{I}_b) \odot (K_p \mathbf{q}_{err,v} - K_d \boldsymbol{\omega})$$

**각속도 PD 제어기 (Mode 4):**
$$\mathbf{T} = -K_p (\boldsymbol{\omega}_{target} - \boldsymbol{\omega}_{actual}) - K_d \mathbf{I}_b^{-1} (\boldsymbol{\omega} \times \mathbf{I}_b \boldsymbol{\omega})$$

### 시뮬레이션 파라미터

| 파라미터 | 값 | 단위 |
|----------|-----|------|
| 지구 중력상수 (μ) | 398600.4418 | km³/s² |
| 지구 반경 (R) | 6378.137 | km |
| J2 계수 | 1.08262668×10⁻³ | - |
| 위성 관성 모멘트 | diag([5, 6, 7]) | kg·m² |
| 휠 관성 모멘트 | diag([0.01, 0.01, 0.01]) | kg·m² |
| 토크 제한 | ±0.05 | Nm |
| 제어기 Kp | 0.03 | - |
| 제어기 Kd | 0.5 | - |

### 초기 궤도 요소

| 요소 | 값 | 단위 |
|------|-----|------|
| 장반경 (a) | 7000 | km |
| 이심률 (e) | 0.01 | - |
| 경사각 (i) | 98 | deg |
| 승교점 경도 (Ω) | 90 | deg |
| 근지점 인수 (ω) | 20 | deg |
| 진근점 이각 (θ) | 0 | deg |

---

##  키보드 단축키

### 제어 모드 전환
| 키 | 모드 |
|----|------|
| `0` | No Control |
| `1` | Rate Damping |
| `2` | Inertial Pointing |
| `3` | Nadir Pointing |
| `4` | Interactive |
| `5` | Momentum Bias |

### 자세 제어 (Mode 4)
| 키 | 동작 |
|----|------|
| `W` | Pitch + |
| `S` | Pitch - |
| `A` | Yaw Left |
| `D` | Yaw Right |
| `Q` | Roll + |
| `E` | Roll - |
| `Space` | Stop |

### 카메라
| 키 | 모드 |
|----|------|
| `F1` | Tracking |
| `F2` | Satellite Wide |
| `F3` | Satellite Zoom |

---

##  문제 해결

### WebSocket 연결 실패

**증상:** Cesium에서 "DISCONNECTED" 표시

**해결:**
1. `websocket_relay04.py`가 실행 중인지 확인
2. 방화벽에서 포트 8765 허용
3. 콘솔에서 에러 메시지 확인

### MATLAB 경로 오류

**증상:** `Undefined function` 에러

**해결:**
```matlab
addpath(genpath('src'));
savepath;  % 영구 저장
```

### Cesium 404 에러

**증상:** 페이지를 찾을 수 없음

**해결:**
- 파일명의 공백을 `%20`으로 인코딩
- 올바른 URL 예시: `http://localhost:8000/cesium_improved-code73%20baseline_7t2.html`

### 텔레메트리 업데이트 안됨

**증상:** 시각화가 정지됨

**해결:**
1. MATLAB 시뮬레이션이 실행 중인지 확인
2. `data/telemetry_out.json` 파일이 업데이트되는지 확인
3. Python 콘솔에서 에러 확인

### 제어 입력이 작동 안함

**증상:** 키보드 입력 무반응

**해결:**
1. Mode 4 (Interactive)인지 확인
2. Cesium 창에 포커스가 있는지 확인
3. `command_in.json` 파일이 생성되는지 확인


얄루 재밌는 위성