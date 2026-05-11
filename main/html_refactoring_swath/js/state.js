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

// Indicator endpoint cache (updated each frame)
let _p = null;
let _velEnd = null;
let _nadirEnd = null;
let _northEnd = null;
let _southEnd = null;
const _vel = new Cesium.Cartesian3();

// WebSocket connection
let socket;
let isConnected = false;
let isFirstMessage = true;

// Camera view listener (for satellite/GSD views)
let satelliteViewListener = null;

// Control mode
let currentControlMode = 7;
let backendControlMode = 7;
let isModePanelExpanded = false;

// Target pointing
let targetMarker, targetLosLine;
let targetEcef = null;

// Real-time graph data
let graphData = {
    time: [],
    rollRateCmd: [], rollRateAct: [],
    pitchRateCmd: [], pitchRateAct: [],
    yawRateCmd: [], yawRateAct: [],
    rollAttCmd: [], rollAttAct: [],
    pitchAttCmd: [], pitchAttAct: [],
    yawAttCmd: [], yawAttAct: []
};

let charts = {
    rollRate: null, pitchRate: null, yawRate: null,
    rollAtt: null, pitchAtt: null, yawAtt: null
};

// Telemetry panel state
let telemetryExpanded = false;
