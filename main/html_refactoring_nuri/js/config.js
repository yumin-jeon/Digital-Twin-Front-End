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

// Projectile Model & Trajectory Paths (relative to index.html)
const PROJECTILE_MODEL_URI       = '../../data/glb/projectile/nuri.glb';
const PROJECTILE_TRAJECTORY_URI  = '../../data/trajectory/projectile/Nuri.json';
const PROJECTILE_MODEL_SCALE     = 50.0;   // GLB 원본 크기에 맞춰 조정