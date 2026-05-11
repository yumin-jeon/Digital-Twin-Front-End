// ================== WebSocket Connection ==================

function connectWebSocket() {
    try {
        socket = new WebSocket(WEBSOCKET_URL);

        socket.onopen = function () {
            console.log("WebSocket connected");
            isConnected = true;
            document.getElementById('connectionStatus').classList.add('connected');
            const status = document.getElementById('summaryStatus');
            status.textContent = 'CONNECTED';
            status.style.color = '#10b981';
        };

        socket.onmessage = function (event) {
            try {
                const data = JSON.parse(event.data);

                if (data.type === 'target_update' || data.targets !== undefined) {
                    _handleTargetUpdate(data);
                    return;
                }

                if (data.simDate && data.position_ecef && data.quaternion) {
                    const isoString = data.simDate.replace(" ", "T") + "Z";
                    const time = Cesium.JulianDate.fromIso8601(
                        new Date(isoString).toISOString()
                    );
                    positionProperty.addSample(
                        time, new Cesium.Cartesian3(...data.position_ecef)
                    );
                    orientationProperty.addSample(
                        time, new Cesium.Quaternion(...data.quaternion)
                    );

                    if (isFirstMessage) {
                        viewer.clock.startTime   = time.clone();
                        viewer.clock.stopTime    = Cesium.JulianDate.addDays(
                            time, 1, new Cesium.JulianDate()
                        );
                        viewer.clock.currentTime = time.clone();
                        viewer.clock.clockStep   = Cesium.ClockStep.SYSTEM_CLOCK_MULTIPLIER;
                        viewer.clock.multiplier  = 1.0;
                        viewer.clock.shouldAnimate = true;
                        satellite.show = true;
                        xAxis.show = true; yAxis.show = true; zAxis.show = true;
                        isFirstMessage = false;
                        scenarioEpoch  = time.clone();
                        switchCameraMode(0);
                        setInterval(recordOrbitPath, 100);
                    }
                }

                updateTelemetryDisplay(data);

            } catch (e) {
                console.error("Error processing message:", e);
            }
        };

        socket.onclose = function () {
            console.log("WebSocket disconnected");
            isConnected = false;
            document.getElementById('connectionStatus').classList.remove('connected');
            const status = document.getElementById('summaryStatus');
            status.textContent = 'DISCONNECTED';
            status.style.color = '#ef4444';
            setTimeout(connectWebSocket, 3000);
        };

    } catch (error) {
        console.error("connectWebSocket error:", error);
    }
}

// ================== Target Update Handler ==================

function _handleTargetUpdate(data) {
    if (!scenarioEpoch || !targetDataSource) return;

    const count     = Array.isArray(data.targets) ? data.targets.length : 0;
    const sampleWin = Array.isArray(data.sample_window) ? data.sample_window : [];

    console.log(
        `[TargetLayer] received target_out: ${count} targets` +
        (sampleWin.length ? `, sample_window=[${sampleWin.join(', ')}]` : '')
    );

    if (!Array.isArray(data.targets)) return;

    data.targets.forEach(target => {
        if (!target.id || !Array.isArray(target.samples) || target.samples.length === 0) return;

        let entity = targetEntityMap[target.id];
        if (!entity) {
            entity = _createTargetEntity(target);
            targetEntityMap[target.id] = entity;
        }

        target.samples.forEach(sample => {
            if (!Array.isArray(sample.position_ecef) || sample.position_ecef.length < 3) return;

            const julianTime = Cesium.JulianDate.addSeconds(
                scenarioEpoch,
                sample.scenario_elapsed,
                new Cesium.JulianDate()
            );
            const position = new Cesium.Cartesian3(
                sample.position_ecef[0],
                sample.position_ecef[1],
                sample.position_ecef[2]
            );
            entity._positionProperty.addSample(julianTime, position);
        });

        const prop = entity._positionProperty;
        if (prop._property && prop._property._times &&
            prop._property._times.length > 60) {
            prop._property._times.splice(0, 30);
            prop._property._values.splice(0, 90); // Cartesian3 = 3 values per sample
        }
    });

    if (targetDataSource) targetDataSource.show = targetLayerVisible;
    _updateTargetLayerUI(count, sampleWin);
}

// ================== Target Entity 생성 ==================

function _getTargetModelUri(target) {
    const type = target.type || 'default';

    if (target.category === 'aircraft') {
        return (typeof AIRCRAFT_GLB_MAP !== 'undefined')
            ? (AIRCRAFT_GLB_MAP[type] || AIRCRAFT_GLB_MAP['default'])
            : null;
    }
    if (target.category === 'ship') {
        return (typeof SHIP_GLB_MAP !== 'undefined')
            ? (SHIP_GLB_MAP[type] || SHIP_GLB_MAP['default'])
            : null;
    }
    if (target.category === 'projectile') {
        return (typeof PROJECTILE_GLB !== 'undefined') ? PROJECTILE_GLB : null;
    }
    return null;
}

function _createTargetEntity(target) {
    const posProp = new Cesium.SampledPositionProperty();

    posProp.setInterpolationOptions({
        interpolationDegree: 1,
        interpolationAlgorithm: Cesium.LinearApproximation
    });
    posProp.forwardExtrapolationType = Cesium.ExtrapolationType.EXTRAPOLATE;
    posProp.backwardExtrapolationType = Cesium.ExtrapolationType.EXTRAPOLATE;

    const oriProp = new Cesium.VelocityOrientationProperty(posProp);

    const colorMap = (typeof TARGET_COLORS !== 'undefined')
        ? TARGET_COLORS
        : { aircraft: Cesium.Color.CYAN, ship: Cesium.Color.LIME,
            projectile: Cesium.Color.RED, default: Cesium.Color.WHITE };
    const color = colorMap[target.category] || colorMap.default;

    const modelUri = _getTargetModelUri(target);

    const visualOptions = modelUri
        ? {
            model: {
                uri:              modelUri,
                scale:            1.0,
                minimumPixelSize: 16,
                colorBlendMode:   Cesium.ColorBlendMode.HIGHLIGHT,
                color:            color
            }
          }
        : {
            point: {
                pixelSize:       10,
                color:           color,
                outlineColor:    Cesium.Color.WHITE,
                outlineWidth:    1,
                scaleByDistance: new Cesium.NearFarScalar(1e3, 2.0, 1e7, 0.5)
            }
          };

    const entity = targetDataSource.entities.add({
        id:          target.id,
        name:        `[${target.category}] ${target.type || target.id}`,
        position:    posProp,
        orientation: oriProp,
        ...visualOptions,
        label: {
            text:            `${target.type || target.id}`,
            font:            '11px sans-serif',
            fillColor:       color,
            pixelOffset:     new Cesium.Cartesian2(0, -18),
            showBackground:  true,
            backgroundColor: Cesium.Color.BLACK.withAlpha(0.6),
            distanceDisplayCondition: new Cesium.DistanceDisplayCondition(
                0,
                (typeof TARGET_LABEL_MAX_DISTANCE !== 'undefined')
                    ? TARGET_LABEL_MAX_DISTANCE : 2e6
            )
        }
    });

    entity._category         = target.category;
    entity._positionProperty = posProp;

    // Heading 폴리라인 
    const HEADING_LENGTH_M = 500000;
    const headingLine = targetDataSource.entities.add({
        show: (typeof targetHeadingVisible !== 'undefined') ? targetHeadingVisible : false,
        polyline: {
            positions: new Cesium.CallbackProperty(function () {
                try {
                    const time = viewer.clock.currentTime;
                    const pos  = posProp.getValue(time);
                    if (!pos) return [];

                    const tFwd   = Cesium.JulianDate.addSeconds(
                        time, 1.0, new Cesium.JulianDate()
                    );
                    const posFwd = posProp.getValue(tFwd);

                    if (!posFwd) return [];
                    if (Cesium.Cartesian3.equalsEpsilon(
                        pos, posFwd, Cesium.Math.EPSILON6)) return [];

                    const vel = new Cesium.Cartesian3();
                    Cesium.Cartesian3.subtract(posFwd, pos, vel);

                    const len = Cesium.Cartesian3.magnitude(vel);
                    if (len < Cesium.Math.EPSILON6) return [];

                    Cesium.Cartesian3.normalize(vel, vel);
                    Cesium.Cartesian3.multiplyByScalar(vel, HEADING_LENGTH_M, vel);

                    const endPos = Cesium.Cartesian3.add(
                        pos, vel, new Cesium.Cartesian3()
                    );
                    return [pos, endPos];
                } catch (err) {
                    return [];
                }
            }, false),
            width:    2,
            material: new Cesium.ColorMaterialProperty(color.withAlpha(0.8))
        }
    });

    entity._headingLine = headingLine;
    return entity;
}