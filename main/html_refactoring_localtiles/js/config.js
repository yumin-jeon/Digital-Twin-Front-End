// ================== Configuration & Constants ==================

// Cesium Ion Access Token
const CESIUM_ION_TOKEN = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJqdGkiOiI2OWU1MTE5Ni1iNjc3LTRhOGMtYjUzNy0wOTYyMjg2ZjRiNjQiLCJpZCI6Mjk0MTAxLCJpYXQiOjE3NDQ2NzgwMzN9.Es400ydfnCqdySgDnXF72GfTjQqXLDa22ZhN1peSsaQ';

// Satellite Body Offset (for camera/indicator positioning)
const BODY_OFFSET = new Cesium.Cartesian3(-30.0, 30.0, 0.0);

// GSD Camera Parameters
const CAMERA_GSD = 0.3;           // meters/pixel
const CAMERA_ALTITUDE = 300000;   // nominal altitude [m]
const CAMERA_PIXEL_SIZE = 5e-6;   // 5 μm
const CAMERA_FOCAL_LENGTH = CAMERA_PIXEL_SIZE * CAMERA_ALTITUDE / CAMERA_GSD;

// Control Mode Names
const MODE_NAMES = [
    'No Control', 'Rate Damping', 'Inertial Pointing',
    'Nadir Pointing', 'Interactive', 'Momentum Bias',
    'Headless', 'Target Pointing'
];

// Chart Configuration
const MAX_DATA_POINTS = 100;

// Keyboard → Button ID Mapping
const KEY_TO_BUTTON_ID = {
    'KeyW': 'btn-w', 'KeyS': 'btn-s', 'KeyA': 'btn-a',
    'KeyD': 'btn-d', 'KeyQ': 'btn-q', 'KeyE': 'btn-e',
    'Space': 'btn-space'
};

// WebSocket URL
const WEBSOCKET_URL = 'ws://localhost:8765';

// Satellite Model Path (relative to index.html)
const SATELLITE_MODEL_URI = '../VLEO_Satellite.glb';

// ================== Local Tile Imagery (External HDD) ==================
// 외장하드에 저장된 XYZ 타일을 불러올 때 true로 전환.
// 별도 HTTP 서버(예: `python -m http.server 8001`)를 외장하드의 타일 루트에서
// 실행해 놓아야 CORS/파일접근 제한을 우회하여 브라우저가 타일을 받을 수 있다.
const USE_LOCAL_TILES = true;

// XYZ 슬리피 맵 포맷: {z}/{x}/{y}.png|jpg (TMS 여부는 TILE_TMS 로 토글)
// 예시)
//   Windows 외장하드 D:\tiles 를 포트 8001에 서빙한 경우:
//     D:\> cd \tiles
//     D:\tiles> python -m http.server 8001
//   URL 템플릿: 'http://localhost:8001/{z}/{x}/{y}.png'
const LOCAL_TILE_URL_TEMPLATE = 'http://localhost:8001/{z}/{x}/{y}.jpg';

// 타일 레벨 범위 (생성 타일셋에 맞춰 조정)
const LOCAL_TILE_MIN_LEVEL = 0;
const LOCAL_TILE_MAX_LEVEL = 18;

// 타일 좌표계: 일반 XYZ는 false, TMS(y축 반전)는 true
const LOCAL_TILE_TMS = false;

// 타일 크레딧 (화면 하단에 표시, 빈 문자열이면 표시 안 함)
const LOCAL_TILE_CREDIT = 'Local HDD Tiles';
