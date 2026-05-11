// ================== Utility Functions ==================

function formatNumber(value, decimals = 2) {
    if (value === undefined || value === null || isNaN(value)) return 'N/A';
    return Number(value).toFixed(decimals);
}

function radToDeg(rad) {
    return rad * (180 / Math.PI);
}

function ecefToLla(x, y, z) {
    const cartesian = new Cesium.Cartesian3(x, y, z);
    const cartographic = Cesium.Cartographic.fromCartesian(cartesian);
    return {
        longitude: Cesium.Math.toDegrees(cartographic.longitude),
        latitude: Cesium.Math.toDegrees(cartographic.latitude),
        altitude: cartographic.height
    };
}

function getBodyAxes(quat) {
    const m = Cesium.Matrix3.fromQuaternion(quat, new Cesium.Matrix3());
    return {
        x: Cesium.Matrix3.getColumn(m, 0, new Cesium.Cartesian3()),
        y: Cesium.Matrix3.getColumn(m, 1, new Cesium.Cartesian3()),
        z: Cesium.Matrix3.getColumn(m, 2, new Cesium.Cartesian3())
    };
}

function applyBodyOffset(pos, quat) {
    if (!BODY_OFFSET || (BODY_OFFSET.x === 0 && BODY_OFFSET.y === 0 && BODY_OFFSET.z === 0)) return pos;
    const rot = Cesium.Matrix3.fromQuaternion(quat, new Cesium.Matrix3());
    const offsetWorld = Cesium.Matrix3.multiplyByVector(rot, BODY_OFFSET, new Cesium.Cartesian3());
    return Cesium.Cartesian3.add(pos, offsetWorld, new Cesium.Cartesian3());
}
