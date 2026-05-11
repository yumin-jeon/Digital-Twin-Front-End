// ================== Configuration & Constants ==================

const CESIUM_ION_TOKEN = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJqdGkiOiI2OWU1MTE5Ni1iNjc3LTRhOGMtYjUzNy0wOTYyMjg2ZjRiNjQiLCJpZCI6Mjk0MTAxLCJpYXQiOjE3NDQ2NzgwMzN9.Es400ydfnCqdySgDnXF72GfTjQqXLDa22ZhN1peSsaQ';

const MODE_NAMES = [
    'No Control', 'Rate Damping', 'Inertial Pointing',
    'Nadir Pointing', 'Interactive', 'Momentum Bias',
    'Headless', 'Target Pointing', 'Target Tracking'
];

const MAX_DATA_POINTS = 100;

const KEY_TO_BUTTON_ID = {
    'KeyW': 'btn-w', 'KeyS': 'btn-s', 'KeyA': 'btn-a',
    'KeyD': 'btn-d', 'KeyQ': 'btn-q', 'KeyE': 'btn-e',
    'Space': 'btn-space'
};

const WEBSOCKET_URL = 'ws://localhost:8765';

const SATELLITE_MODEL_URI = '../VLEO_Satellite.glb';

const TARGET_OUT_PATH    = '../data/target_out.json';
const TELEMETRY_OUT_PATH = '../data/telemetry_out.json';

// Target GLB 매핑 테이블
const TARGET_GLB_BASE = '../data/glb';

const AIRCRAFT_GLB_MAP = {
    'GLF5': `${TARGET_GLB_BASE}/Aircrafts/Kawasaki_LD.glb`,
    'A359': `${TARGET_GLB_BASE}/Aircrafts/A340-600_OBJ.glb`,
    'A321': `${TARGET_GLB_BASE}/Aircrafts/A340-600_OBJ.glb`,
    'B738': `${TARGET_GLB_BASE}/Aircrafts/11805_airplane_v2_L2.glb`,
    'B77W': `${TARGET_GLB_BASE}/Aircrafts/11805_airplane_v2_L2.glb`,
    'default': `${TARGET_GLB_BASE}/Aircrafts/air1.glb`
};

const SHIP_GLB_MAP = {
    '70.0': `${TARGET_GLB_BASE}/Ship/boat_v1_L2..glb`,
    '73.0': `${TARGET_GLB_BASE}/Ship/boat_v1_L2..glb`,
    '79.0': `${TARGET_GLB_BASE}/Ship/m2un5jnd8d-cruisership2012.glb`,
    '80.0': `${TARGET_GLB_BASE}/Ship/elpidifor-413_obj.glb`,
    'default': `${TARGET_GLB_BASE}/Ship/boat_v2_L2..glb`
};

const PROJECTILE_GLB = `${TARGET_GLB_BASE}/projectile/nuri.glb`;