// ================== Cesium Initialization ==================

function buildLocalTileImageryProvider() {
    // UrlTemplateImageryProvider: XYZ/TMS 로컬 타일을 URL 템플릿으로 로드
    const options = {
        url: LOCAL_TILE_URL_TEMPLATE,
        minimumLevel: LOCAL_TILE_MIN_LEVEL,
        maximumLevel: LOCAL_TILE_MAX_LEVEL,
        tilingScheme: new Cesium.WebMercatorTilingScheme(),
        credit: LOCAL_TILE_CREDIT || undefined
    };
    // TMS 좌표계는 Y를 반전 — 템플릿의 {y}를 {reverseY}로 치환
    if (LOCAL_TILE_TMS) {
        options.url = LOCAL_TILE_URL_TEMPLATE.replace('{y}', '{reverseY}');
    }
    return new Cesium.UrlTemplateImageryProvider(options);
}

function initCesium() {
    try {
        Cesium.Ion.defaultAccessToken = CESIUM_ION_TOKEN;

        const viewerOptions = {
            terrainProvider: new Cesium.EllipsoidTerrainProvider(),
            infoBox: false, selectionIndicator: false, shadows: false,
            shouldAnimate: true, baseLayerPicker: false, geocoder: false,
            homeButton: false, sceneModePicker: false, navigationHelpButton: false,
            animation: false, timeline: false, fullscreenButton: false
        };

        // 로컬 타일 사용 시 Cesium Ion 대신 UrlTemplateImageryProvider 주입
        if (USE_LOCAL_TILES) {
            viewerOptions.imageryProvider = buildLocalTileImageryProvider();
            console.log('[Imagery] Using LOCAL HDD tiles:', LOCAL_TILE_URL_TEMPLATE);
        } else {
            console.log('[Imagery] Using default Cesium Ion imagery');
        }

        viewer = new Cesium.Viewer('cesiumContainer', viewerOptions);

        // 로컬 타일 로드 실패 시 기본 Ion 이미지로 폴백
        if (USE_LOCAL_TILES) {
            const layer = viewer.imageryLayers.get(0);
            if (layer && layer.imageryProvider && layer.imageryProvider.errorEvent) {
                let fallbackApplied = false;
                layer.imageryProvider.errorEvent.addEventListener((err) => {
                    if (fallbackApplied) return;
                    fallbackApplied = true;
                    console.warn('[Imagery] Local tile load failed, falling back to Cesium Ion:', err);
                    viewer.imageryLayers.removeAll();
                    viewer.imageryLayers.addImageryProvider(
                        new Cesium.IonImageryProvider({ assetId: 2 })
                    );
                });
            }
        }

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

        xAxis = viewer.entities.add({ ...createAxis(Cesium.Color.RED, axes => axes.x), show: false });
        yAxis = viewer.entities.add({ ...createAxis(Cesium.Color.GREEN, axes => axes.y), show: false });
        zAxis = viewer.entities.add({ ...createAxis(Cesium.Color.BLUE, axes => axes.z), show: false });

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

        orbitalVelocityVector = createIndicator(Cesium.Color.CYAN, 'Velocity', () => _velEnd);
        nadirVector = createIndicator(Cesium.Color.ORANGE, 'Nadir', () => _nadirEnd);
        northVector = createIndicator(Cesium.Color.LIME, 'North', () => _northEnd);
        southVector = createIndicator(Cesium.Color.RED, 'South', () => _southEnd);

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
