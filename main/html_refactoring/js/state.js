// ================== Global Application State ==================

// Cesium entities
let viewer, satellite, orbitEntity;
let xAxis, yAxis, zAxis;
let orbitPoints = [];
let currentCameraMode = 0;

// SampledProperty (interpolated telemetry)
let positionProperty;
let orientationProperty;
let velocityProperty;

// Direction indicator entities
let orbitalVelocityVector;
let nadirVector;
let northVector;
let southVector;

// Indicator endpoint cache
let _p = null;
let _velEnd = null;
let _nadirEnd = null;
let _northEnd = null;
let _southEnd = null;
const _vel = new Cesium.Cartesian3();

// WebSocket connection
let socket;
let isConnected  = false;
let isFirstMessage = true;

// Camera view listener
let satelliteViewListener = null;

// Control mode
let currentControlMode = 7;
let backendControlMode = 7;
let isModePanelExpanded = false;

// Target pointing (Mode 7 고정 지상 타겟)
let targetMarker, targetLosLine;
let targetEcef = null;

// Real-time graph data
let graphData = {
    time: [],
    rollRateCmd: [],  rollRateAct: [],
    pitchRateCmd: [], pitchRateAct: [],
    yawRateCmd: [],   yawRateAct: [],
    rollAttCmd: [],   rollAttAct: [],
    pitchAttCmd: [],  pitchAttAct: [],
    yawAttCmd: [],    yawAttAct: []
};

let charts = {
    rollRate: null, pitchRate: null, yawRate: null,
    rollAtt:  null, pitchAtt:  null, yawAtt:  null
};

// Telemetry panel state
let telemetryExpanded = false;

// Ship / Aircraft (JS 자체 시뮬레이션용)
let shipEntities     = [];
let aircraftEntities = [];

// Target Layer 
let targetDataSource = null;
let targetEntityMap = {};

// scenarioEpoch: 첫 telemetry 수신 시각 (JulianDate)
let scenarioEpoch = null;


// Target category별 Cesium 색상
const TARGET_COLORS = {
    aircraft:   Cesium.Color.CYAN,
    ship:       Cesium.Color.LIME,
    projectile: Cesium.Color.RED,
    default:    Cesium.Color.WHITE
};

// Target label 표시 최대 거리 (m)
const TARGET_LABEL_MAX_DISTANCE = 2e6;
// Camera / Body 설정 (Cesium 로드 후 정의) 
const BODY_OFFSET = new Cesium.Cartesian3(-30.0, 30.0, 0.0);

const CAMERA_GSD          = 0.3;
const CAMERA_ALTITUDE     = 300000;
const CAMERA_PIXEL_SIZE   = 5e-6;
const CAMERA_FOCAL_LENGTH = CAMERA_PIXEL_SIZE * CAMERA_ALTITUDE / CAMERA_GSD;
