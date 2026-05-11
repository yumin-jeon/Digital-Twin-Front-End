// ================== Projectile Trajectory Rendering ==================
//
// Loads a launch-vehicle / projectile trajectory (MATLAB-exported JSON with
// the trace-array schema from outLV: Nominal_Data / Nuri style) and plays
// it back as a Cesium entity alongside the satellite.
//
// Trajectory schema (each row of `trace`):
//   [ time(s),
//     pos_1(lat, rad), pos_2(lon, rad), pos_3(alt, m),
//     vned_1, vned_2, vned_3, vmag,
//     euler_1(yaw, rad), euler_2(pitch, rad), euler_3(roll, rad) ]
//
// Key design choices:
//   - NO `availability` on the entity (always visible; HOLD extrapolation
//     guarantees a defined position at any clock time).
//   - HOLD forward & backward extrapolation on sampled properties.
//   - Trailing past-only polyline implemented via CallbackProperty + an
//     incrementing index (amortized O(1) per frame).
//   - Polyline path decimated 10x for render performance while the GLB
//     position stays on the full sample set for smooth motion.
//   - Idempotent: can be called again to rebuild on a new clock epoch.
// ========================================================================

// ---------- Tuning ----------
const PATH_DECIMATION = 10;  // keep every Nth sample for the trail polyline

// ---------- Loader ----------
async function loadProjectileTrajectory(url) {
    try {
        const response = await fetch(url);
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        const data = await response.json();

        if (!Array.isArray(data.trace) || data.trace.length === 0) {
            console.warn('[projectile] trace array is empty');
            return null;
        }
        console.log(`[projectile] loaded ${data.trace.length} samples from ${url}`);
        return data;
    } catch (err) {
        console.error('[projectile] failed to load trajectory:', err);
        return null;
    }
}

// ---------- Entity Builder ----------
async function initProjectile() {
    if (typeof viewer === 'undefined' || !viewer) {
        console.warn('[projectile] viewer not ready');
        return;
    }

    const data = await loadProjectileTrajectory(PROJECTILE_TRAJECTORY_URI);
    if (!data) return;
    const trace = data.trace;

    // --- Tear down any previous projectile entities (idempotent) ---
    if (projectileEntity)     viewer.entities.remove(projectileEntity);
    if (projectilePathEntity) viewer.entities.remove(projectilePathEntity);
    projectileEntity = null;
    projectilePathEntity = null;

    // --- Epoch = current clock time ---
    const epoch = Cesium.JulianDate.clone(viewer.clock.currentTime);

    // --- Sampled properties with HOLD extrapolation ---
    projectilePositionProperty = new Cesium.SampledPositionProperty();
    projectilePositionProperty.setInterpolationOptions({
        interpolationDegree: 2,
        interpolationAlgorithm: Cesium.LagrangePolynomialApproximation
    });
    projectilePositionProperty.forwardExtrapolationType  = Cesium.ExtrapolationType.HOLD;
    projectilePositionProperty.backwardExtrapolationType = Cesium.ExtrapolationType.HOLD;

    projectileOrientationProperty = new Cesium.SampledProperty(Cesium.Quaternion);
    projectileOrientationProperty.setInterpolationOptions({ interpolationDegree: 1 });
    projectileOrientationProperty.forwardExtrapolationType  = Cesium.ExtrapolationType.HOLD;
    projectileOrientationProperty.backwardExtrapolationType = Cesium.ExtrapolationType.HOLD;

    // --- Iterate trace once: fill sampled properties + build decimated path ---
    const pathPositions = [];   // Cartesian3[] (decimated for polyline)
    const pathTimes     = [];   // JulianDate[]  (decimated for polyline)

    let lastT = 0;
    for (let i = 0; i < trace.length; i++) {
        const s       = trace[i];
        const t       = s[0];
        const latRad  = s[1];
        const lonRad  = s[2];
        const alt     = s[3];
        const yaw     = s[8];
        const pitch   = s[9];
        const roll    = s[10];
        lastT = t;

        const sampleTime = Cesium.JulianDate.addSeconds(epoch, t, new Cesium.JulianDate());
        const position   = Cesium.Cartesian3.fromRadians(lonRad, latRad, alt);

        // 3-2-1 Euler (yaw, pitch, roll) in local ENU -> ECEF quaternion
        const hpr  = new Cesium.HeadingPitchRoll(yaw, pitch, roll);
        const quat = Cesium.Transforms.headingPitchRollQuaternion(position, hpr);

        projectilePositionProperty.addSample(sampleTime, position);
        projectileOrientationProperty.addSample(sampleTime, quat);

        // Decimated sampling for polyline (keep first, every Nth, and last)
        if (i % PATH_DECIMATION === 0 || i === trace.length - 1) {
            pathPositions.push(position);
            pathTimes.push(sampleTime);
        }
    }

    // --- Projectile GLB entity (always visible, position held at endpoints) ---
    projectileEntity = viewer.entities.add({
        name: 'Projectile',
        position: projectilePositionProperty,
        orientation: projectileOrientationProperty,
        model: {
            uri: PROJECTILE_MODEL_URI,
            scale: PROJECTILE_MODEL_SCALE,
            minimumPixelSize: 64,
            maximumScale: 5000
        },
        viewFrom: new Cesium.Cartesian3(-2000, -2000, 800)
    });

    // --- Trailing past-only polyline via CallbackProperty ---
    // Uses an incrementing index so each frame is amortized O(1).
    const visiblePath = [];
    let visibleIdx = -1;

    projectilePathEntity = viewer.entities.add({
        name: 'Projectile Path',
        polyline: {
            positions: new Cesium.CallbackProperty(() => {
                const now = viewer.clock.currentTime;

                // Advance forward when clock has moved past additional samples
                while (visibleIdx + 1 < pathTimes.length &&
                       Cesium.JulianDate.compare(pathTimes[visibleIdx + 1], now) <= 0) {
                    visibleIdx++;
                    visiblePath.push(pathPositions[visibleIdx]);
                }
                // Retreat if clock went backward (e.g. user scrubbed timeline)
                while (visibleIdx >= 0 &&
                       Cesium.JulianDate.compare(pathTimes[visibleIdx], now) > 0) {
                    visiblePath.pop();
                    visibleIdx--;
                }
                // Polyline requires >= 2 points to draw
                return visiblePath.length >= 2 ? visiblePath : [];
            }, false),
            width: 2,
            material: new Cesium.PolylineGlowMaterialProperty({
                glowPower: 0.2,
                color: Cesium.Color.MAGENTA
            }),
            clampToGround: false,
            arcType: Cesium.ArcType.NONE   // straight 3-D segments, no ground projection
        }
    });

    // --- Ensure clock is actually running ---
    viewer.clock.shouldAnimate = true;
    if (viewer.clock.multiplier <= 0) viewer.clock.multiplier = 1.0;

    // --- Extend clock stop time so playback isn't clipped ---
    const stopTime = Cesium.JulianDate.addSeconds(epoch, lastT, new Cesium.JulianDate());
    if (Cesium.JulianDate.compare(stopTime, viewer.clock.stopTime) > 0) {
        viewer.clock.stopTime = stopTime;
    }

    console.log(
        `[projectile] ready.\n` +
        `  epoch=${Cesium.JulianDate.toIso8601(epoch)}\n` +
        `  duration=${lastT.toFixed(2)}s  samples=${trace.length}  path-points=${pathPositions.length}\n` +
        `  shouldAnimate=${viewer.clock.shouldAnimate}  multiplier=${viewer.clock.multiplier}`
    );
}

// ---------- Utility helpers ----------
function setProjectileVisible(visible) {
    if (projectileEntity)     projectileEntity.show     = visible;
    if (projectilePathEntity) projectilePathEntity.show = visible;
}

function focusProjectile() {
    if (projectileEntity) viewer.flyTo(projectileEntity);
}

// Run in DevTools to diagnose where the projectile is:
//   logProjectileState()
function logProjectileState() {
    if (!projectileEntity || !projectilePositionProperty) {
        console.log('[projectile] no entity/property yet');
        return;
    }
    const t = viewer.clock.currentTime;
    const pos = projectilePositionProperty.getValue(t);
    if (!pos) {
        console.log('[projectile] position is UNDEFINED at current clock time');
        return;
    }
    const carto = Cesium.Cartographic.fromCartesian(pos);
    console.log(
        `[projectile] clock=${Cesium.JulianDate.toIso8601(t)}\n` +
        `  lat=${Cesium.Math.toDegrees(carto.latitude).toFixed(5)}°  ` +
        `lon=${Cesium.Math.toDegrees(carto.longitude).toFixed(5)}°  ` +
        `alt=${carto.height.toFixed(1)} m\n` +
        `  shouldAnimate=${viewer.clock.shouldAnimate}  multiplier=${viewer.clock.multiplier}  ` +
        `show=${projectileEntity.show}`
    );
}
