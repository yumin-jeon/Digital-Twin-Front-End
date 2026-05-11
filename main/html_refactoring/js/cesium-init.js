// ================== Cesium Initialization ==================

function initCesium() {
    try {
        Cesium.Ion.defaultAccessToken = CESIUM_ION_TOKEN;

        viewer = new Cesium.Viewer('cesiumContainer', {
            terrainProvider: new Cesium.EllipsoidTerrainProvider(),
            infoBox: false, selectionIndicator: false, shadows: false,
            shouldAnimate: true, baseLayerPicker: false, geocoder: false,
            homeButton: false, sceneModePicker: false, navigationHelpButton: false,
            animation: false, timeline: false, fullscreenButton: false
        });
        viewer.cesiumWidget.creditContainer.style.display = 'none';

        // Interpolated position/orientation properties
        positionProperty = new Cesium.SampledPositionProperty();
        orientationProperty = new Cesium.SampledProperty(Cesium.Quaternion);
        positionProperty.setInterpolationOptions({
            interpolationDegree: 2,
            interpolationAlgorithm: Cesium.LagrangePolynomialApproximation
        });
        orientationProperty.setInterpolationOptions({ interpolationDegree: 1 });
        positionProperty.forwardExtrapolationType = Cesium.ExtrapolationType.EXTRAPOLATE;
        orientationProperty.forwardExtrapolationType = Cesium.ExtrapolationType.EXTRAPOLATE;
        velocityProperty = new Cesium.VelocityVectorProperty(positionProperty);

        viewer.camera.frustum.near = 0.01;

        // Satellite entity
        satellite = viewer.entities.add({
            name: 'Satellite', show: false,
            position: positionProperty, orientation: orientationProperty,
            model: { uri: SATELLITE_MODEL_URI, scale: 10.0, minimumPixelSize: 200, maximumScale: 20000 },
            viewFrom: new Cesium.Cartesian3(0, -15000, 8000)
        });

        // Body-fixed axes
        const axisLength = 4000;
        const axisWidth = 4;
        const halfLen = axisLength * 0.5;

        const createAxis = (color, getVector) => ({
            polyline: {
                positions: new Cesium.CallbackProperty(time => {
                    const pos = positionProperty.getValue(time);
                    const quat = orientationProperty.getValue(time);
                    if (!pos || !quat) return [];
                    const base = applyBodyOffset(pos, quat);
                    const axes = getBodyAxes(quat);
                    const vec = getVector(axes);
                    return [
                        Cesium.Cartesian3.add(base, Cesium.Cartesian3.multiplyByScalar(vec, -halfLen, new Cesium.Cartesian3()), new Cesium.Cartesian3()),
                        Cesium.Cartesian3.add(base, Cesium.Cartesian3.multiplyByScalar(vec, halfLen, new Cesium.Cartesian3()), new Cesium.Cartesian3())
                    ];
                }, false),
                width: axisWidth,
                material: new Cesium.PolylineArrowMaterialProperty(color)
            }
        });

        xAxis = viewer.entities.add({ ...createAxis(Cesium.Color.RED,   axes => axes.x), show: false });
        yAxis = viewer.entities.add({ ...createAxis(Cesium.Color.GREEN, axes => axes.y), show: false });
        zAxis = viewer.entities.add({ ...createAxis(Cesium.Color.BLUE,  axes => axes.z), show: false });

        // Orbit trail
        orbitEntity = viewer.entities.add({
            polyline: {
                positions: new Cesium.CallbackProperty(() => orbitPoints, false),
                width: 2,
                material: new Cesium.PolylineGlowMaterialProperty({ glowPower: 0.1, color: Cesium.Color.YELLOW })
            }
        });

        // Direction indicators
        const createIndicator = (color, name, getEnd) => viewer.entities.add({
            name: name, show: false,
            position: new Cesium.CallbackProperty(() => getEnd(), false),
            polyline: {
                positions: new Cesium.CallbackProperty(() => (_p && getEnd()) ? [_p, getEnd()] : [], false),
                width: 3,
                material: new Cesium.PolylineGlowMaterialProperty({ glowPower: 0.25, color: color.withAlpha(0.9) })
            },
            label: {
                text: name, font: '12px sans-serif', fillColor: color,
                pixelOffset: new Cesium.Cartesian2(12, 0),
                showBackground: true, backgroundColor: Cesium.Color.BLACK.withAlpha(0.6)
            }
        });

        orbitalVelocityVector = createIndicator(Cesium.Color.CYAN,   'Velocity', () => _velEnd);
        nadirVector           = createIndicator(Cesium.Color.ORANGE, 'Nadir',    () => _nadirEnd);
        northVector           = createIndicator(Cesium.Color.LIME,   'North',    () => _northEnd);
        southVector           = createIndicator(Cesium.Color.RED,    'South',    () => _southEnd);

        // ================== Target DataSource 초기화 ==================
        targetDataSource = new Cesium.CustomDataSource('targets');
        viewer.dataSources.add(targetDataSource);

        // ================== 타겟 클릭 이벤트 ==================
        viewer.screenSpaceEventHandler.setInputAction(function (click) {
            const picked = viewer.scene.pick(click.position);
            if (!Cesium.defined(picked) || !Cesium.defined(picked.id)) return;

            const entity = picked.id;
            if (!targetDataSource.entities.contains(entity)) return;

            const targetId = entity.id;
            console.log(`[TargetLayer] clicked target: ${targetId}`);

            if (socket && socket.readyState === WebSocket.OPEN) {
                socket.send(JSON.stringify({
                    type:      'target_select',
                    target_id: targetId
                }));
            }

            _highlightTarget(targetId);

        }, Cesium.ScreenSpaceEventType.LEFT_CLICK);

        viewer.camera.flyTo({
            destination: Cesium.Cartesian3.fromDegrees(126.5, 33.2, 50000)
        });

    } catch (error) {
        console.error("initCesium error:", error);
    }
}

function recordOrbitPath() {
    const currentPosition = positionProperty.getValue(viewer.clock.currentTime);
    if (currentPosition) {
        orbitPoints.push(Cesium.Cartesian3.clone(currentPosition));
        if (orbitPoints.length > 300) orbitPoints.shift();
    }
}

// ================== Target 강조 표시 ==================
let _selectedTargetId = null;

function _highlightTarget(targetId) {
    if (_selectedTargetId) {
        const prev = targetDataSource.entities.getById(_selectedTargetId);
        if (prev && prev.point) {
            const cat = prev._category || 'default';
            prev.point.color = new Cesium.ConstantProperty(
                TARGET_COLORS[cat] || TARGET_COLORS.default
            );
        }
    }
    const entity = targetDataSource.entities.getById(targetId);
    if (entity && entity.point) {
        entity.point.color = new Cesium.ConstantProperty(Cesium.Color.YELLOW);
    }
    _selectedTargetId = targetId;
}
