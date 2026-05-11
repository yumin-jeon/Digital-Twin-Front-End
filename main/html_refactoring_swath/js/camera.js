// ================== Camera Modes ==================

function setupSatelliteView() {
    if (satelliteViewListener) { satelliteViewListener(); satelliteViewListener = null; }
    viewer.trackedEntity = undefined;
    viewer.camera.lookAtTransform(Cesium.Matrix4.IDENTITY);

    const listener = function () {
        const t = viewer.clock.currentTime;
        const pos = positionProperty.getValue(t);
        const quat = orientationProperty.getValue(t);
        if (!pos || !quat) return;

        const basePos = applyBodyOffset(pos, quat);
        const axes = getBodyAxes(quat);
        const forward = Cesium.Cartesian3.normalize(axes.z, new Cesium.Cartesian3());
        const up = Cesium.Cartesian3.normalize(axes.y, new Cesium.Cartesian3());
        const camOffset = (currentCameraMode === 1) ? 0.1 : 0.5;
        const camPos = Cesium.Cartesian3.add(basePos,
            Cesium.Cartesian3.multiplyByScalar(forward, -camOffset, new Cesium.Cartesian3()),
            new Cesium.Cartesian3());

        // Rotate up vector by -90 degrees around forward axis
        const rotationAngle = Cesium.Math.toRadians(-90);
        const rotationQuat = Cesium.Quaternion.fromAxisAngle(forward, rotationAngle);
        const rotationMatrix = Cesium.Matrix3.fromQuaternion(rotationQuat, new Cesium.Matrix3());
        const rotatedUp = Cesium.Matrix3.multiplyByVector(rotationMatrix, up, new Cesium.Cartesian3());

        viewer.camera.position = camPos;
        viewer.camera.direction = forward;
        viewer.camera.up = rotatedUp;
        viewer.camera.frustum.fov = Cesium.Math.toRadians(currentCameraMode === 1 ? 0.7 : 15.0);
        updateDirectionIndicatorsForSatelliteView(camPos, forward, rotatedUp, quat);
    };
    satelliteViewListener = viewer.scene.preUpdate.addEventListener(listener);
}

function setupGSDView() {
    if (satelliteViewListener) { satelliteViewListener(); satelliteViewListener = null; }
    viewer.trackedEntity = undefined;
    viewer.camera.lookAtTransform(Cesium.Matrix4.IDENTITY);

    const listener = function () {
        const t = viewer.clock.currentTime;
        const pos = positionProperty.getValue(t);
        const quat = orientationProperty.getValue(t);
        if (!pos || !quat) return;

        const axes = getBodyAxes(quat);
        const forward = Cesium.Cartesian3.normalize(axes.z, new Cesium.Cartesian3());
        const up = Cesium.Cartesian3.normalize(axes.y, new Cesium.Cartesian3());

        // Rotate up by -90 deg around forward (same convention as satellite view)
        const rotQuat = Cesium.Quaternion.fromAxisAngle(forward, Cesium.Math.toRadians(-90));
        const rotMat = Cesium.Matrix3.fromQuaternion(rotQuat, new Cesium.Matrix3());
        const rotatedUp = Cesium.Matrix3.multiplyByVector(rotMat, up, new Cesium.Cartesian3());

        // Compute FOV so 1 screen pixel = CAMERA_GSD meters on the ground
        const cartographic = Cesium.Cartographic.fromCartesian(pos);
        const altitudeM = cartographic.height;
        const canvasHeight = viewer.canvas.height;
        const canvasWidth = viewer.canvas.width;
        const vfov = 2 * Math.atan(canvasHeight * CAMERA_GSD / (2 * altitudeM));

        viewer.camera.position = Cesium.Cartesian3.clone(pos);
        viewer.camera.direction = forward;
        viewer.camera.up = rotatedUp;
        viewer.camera.frustum.fov = vfov;

        // Update GSD overlay info
        const groundW = (canvasWidth * CAMERA_GSD).toFixed(0);
        const groundH = (canvasHeight * CAMERA_GSD).toFixed(0);
        const fovDeg = Cesium.Math.toDegrees(vfov);

        const coverageEl = document.getElementById('gsdCoverageDisplay');
        const altEl = document.getElementById('gsdAltDisplay');
        const fovEl = document.getElementById('gsdFovDisplay');
        if (coverageEl) coverageEl.textContent = groundW + ' x ' + groundH + ' m';
        if (altEl) altEl.textContent = (altitudeM / 1000).toFixed(1) + ' km';
        if (fovEl) fovEl.textContent = fovDeg.toFixed(4) + String.fromCharCode(176);

        updateGSDScalebar(canvasWidth);
    };
    satelliteViewListener = viewer.scene.preUpdate.addEventListener(listener);
}

function updateGSDScalebar(canvasWidth) {
    const niceDistances = [10, 20, 50, 100, 200, 500];
    const maxBarPx = canvasWidth * 0.3;
    let bestDist = niceDistances[0];
    for (const d of niceDistances) {
        if (d / CAMERA_GSD <= maxBarPx) bestDist = d;
    }
    const barPx = bestDist / CAMERA_GSD;
    const barLine = document.getElementById('gsdScalebarLine');
    const barText = document.getElementById('gsdScalebarText');
    if (barLine) barLine.style.width = barPx + 'px';
    if (barText) barText.textContent = bestDist + ' m';
}

function setupSwathView() {
    if (satelliteViewListener) { satelliteViewListener(); satelliteViewListener = null; }
    viewer.trackedEntity = undefined;
    viewer.camera.lookAtTransform(Cesium.Matrix4.IDENTITY);

    const listener = function () {
        const t = viewer.clock.currentTime;
        const pos = positionProperty.getValue(t);
        const quat = orientationProperty.getValue(t);
        if (!pos || !quat) return;

        const axes = getBodyAxes(quat);
        const forward = Cesium.Cartesian3.normalize(axes.z, new Cesium.Cartesian3());
        const up = Cesium.Cartesian3.normalize(axes.y, new Cesium.Cartesian3());

        // Rotate up by -90 deg around forward (same convention as satellite view)
        const rotQuat = Cesium.Quaternion.fromAxisAngle(forward, Cesium.Math.toRadians(-90));
        const rotMat = Cesium.Matrix3.fromQuaternion(rotQuat, new Cesium.Matrix3());
        const rotatedUp = Cesium.Matrix3.multiplyByVector(rotMat, up, new Cesium.Cartesian3());

        // FOV so the full swath (SWATH_WIDTH) fits the vertical screen extent
        const cartographic = Cesium.Cartographic.fromCartesian(pos);
        const altitudeM = cartographic.height;
        const vfov = 2 * Math.atan(SWATH_WIDTH / (2 * altitudeM));

        viewer.camera.position = Cesium.Cartesian3.clone(pos);
        viewer.camera.direction = forward;
        viewer.camera.up = rotatedUp;
        viewer.camera.frustum.fov = vfov;

        // Update Swath overlay info
        const canvasWidth = viewer.canvas.width;
        const canvasHeight = viewer.canvas.height;
        const aspect = canvasWidth / canvasHeight;
        // Vertical ground coverage = SWATH_WIDTH; horizontal = swath * aspect
        const groundV = SWATH_WIDTH;
        const groundH = SWATH_WIDTH * aspect;
        const fovDeg = Cesium.Math.toDegrees(vfov);

        const gsdEl = document.getElementById('swathGsdDisplay');
        const npixEl = document.getElementById('swathNpixDisplay');
        const pixelEl = document.getElementById('swathPixelDisplay');
        const swathEl = document.getElementById('swathWidthDisplay');
        const altEl = document.getElementById('swathAltDisplay');
        const fovEl = document.getElementById('swathFovDisplay');
        const coverageEl = document.getElementById('swathCoverageDisplay');

        if (gsdEl) gsdEl.textContent = SWATH_GSD.toFixed(2) + ' m/px';
        if (npixEl) npixEl.textContent = SWATH_N_PIX.toString() + ' px';
        if (pixelEl) pixelEl.textContent = (CAMERA_PIXEL_SIZE * 1e6).toFixed(1) + ' μm';
        if (swathEl) swathEl.textContent = (SWATH_WIDTH / 1000).toFixed(2) + ' km';
        if (altEl) altEl.textContent = (altitudeM / 1000).toFixed(1) + ' km';
        if (fovEl) fovEl.textContent = fovDeg.toFixed(3) + String.fromCharCode(176);
        if (coverageEl) coverageEl.textContent = (groundH / 1000).toFixed(1) + ' x ' + (groundV / 1000).toFixed(1) + ' km';

        updateSwathScalebar(canvasWidth, altitudeM, vfov);
    };
    satelliteViewListener = viewer.scene.preUpdate.addEventListener(listener);
}

function updateSwathScalebar(canvasWidth, altitudeM, vfov) {
    // Screen meters per pixel at ground level (using vertical extent of screen)
    const canvasHeight = viewer.canvas.height;
    const screenGroundV = 2 * altitudeM * Math.tan(vfov / 2);   // vertical ground extent
    const mPerPx = screenGroundV / canvasHeight;

    // Pick a "nice" distance for the scale bar (in meters)
    const niceDistances = [1000, 2000, 5000, 10000, 20000, 50000, 100000];
    const maxBarPx = canvasWidth * 0.3;
    let bestDist = niceDistances[0];
    for (const d of niceDistances) {
        if (d / mPerPx <= maxBarPx) bestDist = d;
    }
    const barPx = bestDist / mPerPx;
    const barLine = document.getElementById('swathScalebarLine');
    const barText = document.getElementById('swathScalebarText');
    if (barLine) barLine.style.width = barPx + 'px';
    if (barText) barText.textContent = (bestDist / 1000) + ' km';
}

function switchCameraMode(mode) {
    currentCameraMode = mode;
    const modeText = document.getElementById('cameraMode');
    const legendPanel = document.getElementById('legendPanel');
    const gsdOverlay = document.getElementById('gsdOverlay');
    const gsdCrosshair = document.getElementById('gsdCrosshair');
    const swathOverlay = document.getElementById('swathOverlay');
    const swathCrosshair = document.getElementById('swathCrosshair');
    if (satelliteViewListener) { satelliteViewListener(); satelliteViewListener = null; }

    // Hide all special overlays by default
    if (gsdOverlay) gsdOverlay.classList.remove('visible');
    if (gsdCrosshair) gsdCrosshair.classList.remove('visible');
    if (swathOverlay) swathOverlay.classList.remove('visible');
    if (swathCrosshair) swathCrosshair.classList.remove('visible');

    if (mode === 0) {
        // Tracking view
        viewer.camera.lookAtTransform(Cesium.Matrix4.IDENTITY);
        viewer.camera.frustum.fov = Cesium.Math.toRadians(60.0);
        satellite.show = true;
        orbitEntity.show = true;
        viewer.trackedEntity = satellite;
        modeText.textContent = "Tracking (Zoom 가능)";
        setIndicatorsVisible(false);
        if (legendPanel) legendPanel.classList.remove('visible');
        xAxis.show = true; yAxis.show = true; zAxis.show = true;
    } else if (mode === 3) {
        // GSD View — hide satellite model
        viewer.trackedEntity = undefined;
        satellite.show = false;
        orbitEntity.show = false;
        modeText.textContent = "GSD View (1px = " + CAMERA_GSD + "m)";
        setIndicatorsVisible(false);
        if (legendPanel) legendPanel.classList.remove('visible');
        if (gsdOverlay) gsdOverlay.classList.add('visible');
        if (gsdCrosshair) gsdCrosshair.classList.add('visible');
        xAxis.show = false; yAxis.show = false; zAxis.show = false;
        setupGSDView();
    } else if (mode === 4) {
        // Swath View — shows ground swath = GSD × N_pix
        viewer.trackedEntity = undefined;
        satellite.show = false;
        orbitEntity.show = false;
        modeText.textContent = "Swath View (" + (SWATH_WIDTH / 1000).toFixed(1) + " km)";
        setIndicatorsVisible(false);
        if (legendPanel) legendPanel.classList.remove('visible');
        if (swathOverlay) swathOverlay.classList.add('visible');
        if (swathCrosshair) swathCrosshair.classList.add('visible');
        xAxis.show = false; yAxis.show = false; zAxis.show = false;
        setupSwathView();
    } else {
        // Satellite views (mode 1 = narrow FOV, mode 2 = wide FOV)
        viewer.trackedEntity = undefined;
        satellite.show = true;
        orbitEntity.show = true;
        modeText.textContent = (mode === 1) ? "Satellite View (0.7° FOV)" : "Satellite View (15° FOV)";
        setIndicatorsVisible(true);
        if (legendPanel) legendPanel.classList.add('visible');
        xAxis.show = false; yAxis.show = false; zAxis.show = false;
        setupSatelliteView();
    }

    const t = viewer.clock.currentTime;
    const pos = positionProperty.getValue(t);
    const quat = orientationProperty.getValue(t);
    if (pos && quat) updateDirectionIndicators(pos, quat);
}
