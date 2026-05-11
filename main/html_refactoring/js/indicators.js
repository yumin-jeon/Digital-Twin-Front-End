// ================== Direction Indicators ==================

function updateDirectionIndicators(position, quat) {
    try {
        const epsilon = 1e-3, L = 8000;
        const t = viewer.clock.currentTime;

        const basePos = applyBodyOffset(position, quat);
        _p = basePos;

        // Velocity
        let v = velocityProperty.getValue(t, _vel);
        if (Cesium.defined(v) && Cesium.Cartesian3.magnitude(v) > epsilon) {
            _velEnd = Cesium.Cartesian3.add(basePos,
                Cesium.Cartesian3.multiplyByScalar(
                    Cesium.Cartesian3.normalize(v, new Cesium.Cartesian3()), L, new Cesium.Cartesian3()),
                new Cesium.Cartesian3());
        } else {
            _velEnd = null;
        }

        // Nadir
        if (Cesium.Cartesian3.magnitude(position) > epsilon) {
            const nadirDir = Cesium.Cartesian3.normalize(
                Cesium.Cartesian3.negate(position, new Cesium.Cartesian3()), new Cesium.Cartesian3());
            _nadirEnd = Cesium.Cartesian3.add(basePos,
                Cesium.Cartesian3.multiplyByScalar(nadirDir, L, new Cesium.Cartesian3()),
                new Cesium.Cartesian3());
        } else {
            _nadirEnd = null;
        }

        // North / South
        if (_nadirEnd) {
            const enu = Cesium.Transforms.eastNorthUpToFixedFrame(position, Cesium.Ellipsoid.WGS84);
            const rot = Cesium.Matrix4.getMatrix3(enu, new Cesium.Matrix3());
            const north = Cesium.Matrix3.getColumn(rot, 1, new Cesium.Cartesian3());
            const northN = Cesium.Cartesian3.normalize(north, new Cesium.Cartesian3());
            _northEnd = Cesium.Cartesian3.add(basePos,
                Cesium.Cartesian3.multiplyByScalar(northN, L, new Cesium.Cartesian3()),
                new Cesium.Cartesian3());
            _southEnd = Cesium.Cartesian3.add(basePos,
                Cesium.Cartesian3.multiplyByScalar(
                    Cesium.Cartesian3.negate(northN, new Cesium.Cartesian3()), L, new Cesium.Cartesian3()),
                new Cesium.Cartesian3());
        } else {
            _northEnd = _southEnd = null;
        }
    } catch (e) { }
}

function setIndicatorsVisible(flag) {
    [orbitalVelocityVector, nadirVector, northVector, southVector].forEach(e => {
        if (e) {
            e.show = flag;
            if (e.polyline) e.polyline.show = flag;
            if (e.label) e.label.show = flag;
        }
    });
}

function updateDirectionIndicatorsForSatelliteView(camPos, camForward, camUp, quat) {
    try {
        const t = viewer.clock.currentTime;
        const satPos = positionProperty.getValue(t);
        if (!satPos) return;

        const indicatorDistance = (currentCameraMode === 1) ? 50000 : 20000;
        const indicatorLength = (currentCameraMode === 1) ? 15000 : 8000;

        const indicatorStart = Cesium.Cartesian3.add(
            camPos,
            Cesium.Cartesian3.multiplyByScalar(camForward, indicatorDistance, new Cesium.Cartesian3()),
            new Cesium.Cartesian3()
        );
        _p = indicatorStart;

        const epsilon = 1e-3;

        // Velocity
        let v = velocityProperty.getValue(t, _vel);
        if (Cesium.defined(v) && Cesium.Cartesian3.magnitude(v) > epsilon) {
            const dir = Cesium.Cartesian3.normalize(v, new Cesium.Cartesian3());
            _velEnd = Cesium.Cartesian3.add(indicatorStart,
                Cesium.Cartesian3.multiplyByScalar(dir, indicatorLength, new Cesium.Cartesian3()),
                new Cesium.Cartesian3());
        } else {
            _velEnd = null;
        }

        // Nadir
        if (Cesium.Cartesian3.magnitude(satPos) > epsilon) {
            const nadirDir = Cesium.Cartesian3.normalize(
                Cesium.Cartesian3.negate(satPos, new Cesium.Cartesian3()),
                new Cesium.Cartesian3()
            );
            _nadirEnd = Cesium.Cartesian3.add(indicatorStart,
                Cesium.Cartesian3.multiplyByScalar(nadirDir, indicatorLength, new Cesium.Cartesian3()),
                new Cesium.Cartesian3());
        } else {
            _nadirEnd = null;
        }

        // North / South
        if (_nadirEnd) {
            const enu = Cesium.Transforms.eastNorthUpToFixedFrame(satPos, Cesium.Ellipsoid.WGS84);
            const rot = Cesium.Matrix4.getMatrix3(enu, new Cesium.Matrix3());
            const north = Cesium.Matrix3.getColumn(rot, 1, new Cesium.Cartesian3());
            const northN = Cesium.Cartesian3.normalize(north, new Cesium.Cartesian3());

            _northEnd = Cesium.Cartesian3.add(indicatorStart,
                Cesium.Cartesian3.multiplyByScalar(northN, indicatorLength, new Cesium.Cartesian3()),
                new Cesium.Cartesian3());
            _southEnd = Cesium.Cartesian3.add(indicatorStart,
                Cesium.Cartesian3.multiplyByScalar(
                    Cesium.Cartesian3.negate(northN, new Cesium.Cartesian3()),
                    indicatorLength, new Cesium.Cartesian3()),
                new Cesium.Cartesian3());
        } else {
            _northEnd = _southEnd = null;
        }
    } catch (e) {
        console.error("updateDirectionIndicatorsForSatelliteView error:", e);
    }
}
