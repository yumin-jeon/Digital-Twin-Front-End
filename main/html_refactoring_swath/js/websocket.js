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

                if (data.simDate && data.position_ecef && data.quaternion) {
                    const isoString = data.simDate.replace(" ", "T") + "Z";
                    const time = Cesium.JulianDate.fromIso8601(new Date(isoString).toISOString());
                    positionProperty.addSample(time, new Cesium.Cartesian3(...data.position_ecef));
                    orientationProperty.addSample(time, new Cesium.Quaternion(...data.quaternion));

                    if (isFirstMessage) {
                        viewer.clock.startTime = time.clone();
                        viewer.clock.stopTime = Cesium.JulianDate.addDays(time, 1, new Cesium.JulianDate());
                        viewer.clock.currentTime = time.clone();
                        viewer.clock.clockStep = Cesium.ClockStep.SYSTEM_CLOCK_MULTIPLIER;
                        viewer.clock.multiplier = 1.0;
                        viewer.clock.shouldAnimate = true;
                        satellite.show = true;
                        xAxis.show = true; yAxis.show = true; zAxis.show = true;
                        isFirstMessage = false;
                        switchCameraMode(0);
                        setInterval(recordOrbitPath, 100);
                    }
                }

                updateTelemetryDisplay(data);
            } catch (e) {
                console.error("Error processing telemetry:", e);
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
