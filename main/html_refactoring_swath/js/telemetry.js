// ================== Telemetry UI ==================

function toggleTelemetryDetails() {
    telemetryExpanded = !telemetryExpanded;
    const details = document.getElementById('telemetryDetails');
    const icon = document.getElementById('telemetryToggleIcon');
    if (telemetryExpanded) {
        details.classList.add('expanded');
        icon.classList.add('expanded');
    } else {
        details.classList.remove('expanded');
        icon.classList.remove('expanded');
    }
}

function updateTelemetryDisplay(data) {
    try {
        if (data.ctrl_mode !== undefined) {
            updateBackendModeDisplay(data.ctrl_mode, data.ctrl_mode_name);
        }

        // Calculate LLA from ECEF
        let altitude = '--', lat = '--', lon = '--';
        if (data.position_ecef) {
            try {
                const lla = ecefToLla(data.position_ecef[0], data.position_ecef[1], data.position_ecef[2]);
                altitude = formatNumber(lla.altitude / 1000, 1) + ' km';
                lat = formatNumber(lla.latitude, 2) + '\u00B0';
                lon = formatNumber(lla.longitude, 2) + '\u00B0';
            } catch (e) { }
        }

        // Summary row updates
        document.getElementById('summaryMode').textContent =
            data.ctrl_mode !== undefined
                ? `${data.ctrl_mode}: ${(data.ctrl_mode_name || MODE_NAMES[data.ctrl_mode]).substring(0, 12)}`
                : '--';
        document.getElementById('summaryTime').textContent =
            data.time !== undefined ? formatNumber(data.time, 0) + 's' : '--';

        // Detailed telemetry HTML
        let html = `
            <div class="telemetry-section" style="margin-top:0; padding-top:0; border-top:none;">
                <div class="section-title">TIME</div>
                <div>Sim Time: ${formatNumber(data.time, 1)} s</div>
                <div>Date: ${data.simDate || 'N/A'}</div>
            </div>
        `;

        if (data.ctrl_mode !== undefined) {
            html += `<div class="mode-indicator mode-${data.ctrl_mode}">${data.ctrl_mode} - ${data.ctrl_mode_name || MODE_NAMES[data.ctrl_mode]}</div>`;
        }

        if (data.position_ecef) {
            html += `<div class="telemetry-section"><div class="section-title">POSITION</div>
                <div style="display:flex; justify-content:space-between;"><span>Lat:</span> <span style="color:white">${lat}</span></div>
                <div style="display:flex; justify-content:space-between;"><span>Lon:</span> <span style="color:white">${lon}</span></div>
                <div style="display:flex; justify-content:space-between;"><span>Alt:</span> <span style="color:white">${altitude}</span></div></div>`;
        }

        if (data.pointing_error_deg !== undefined) {
            const c = data.pointing_error_deg < 1 ? '#4caf50' : data.pointing_error_deg < 5 ? '#ff9800' : '#f44336';
            html += `<div class="telemetry-section"><div class="section-title">POINTING ERROR</div>
                <div style="font-size: 18px; font-weight: bold; color: ${c}; text-align:right;">${formatNumber(data.pointing_error_deg, 3)}\u00B0</div></div>`;
        }

        if (data.wheel_speeds_rpm) {
            html += `<div class="telemetry-section"><div class="section-title">WHEEL SPEED (rpm)</div>
                <div style="display:flex; justify-content:space-between;"><span>X:</span> <span style="color:white">${formatNumber(data.wheel_speeds_rpm[0], 1)}</span></div>
                <div style="display:flex; justify-content:space-between;"><span>Y:</span> <span style="color:white">${formatNumber(data.wheel_speeds_rpm[1], 1)}</span></div>
                <div style="display:flex; justify-content:space-between;"><span>Z:</span> <span style="color:white">${formatNumber(data.wheel_speeds_rpm[2], 1)}</span></div></div>`;
        }

        // Target Pointing info (Mode 7)
        if (data.ctrl_mode === 7 && data.target_name) {
            const onaColor = data.off_nadir_deg < 30 ? '#4caf50' : data.off_nadir_deg < 60 ? '#ff9800' : '#f44336';
            html += `<div class="telemetry-section"><div class="section-title" style="color:#e879f9;">\uD83C\uDFAF TARGET: ${data.target_name}</div>
                <div style="display:flex; justify-content:space-between;"><span>LOS Distance:</span> <span style="color:white">${formatNumber(data.los_distance_km, 1)} km</span></div>
                <div style="display:flex; justify-content:space-between;"><span>Off-Nadir:</span> <span style="color:${onaColor}">${formatNumber(data.off_nadir_deg, 1)}\u00B0</span></div></div>`;
        }

        // Toggle target entities visibility
        const isTargetMode = (data.ctrl_mode === 7);
        if (targetMarker) targetMarker.show = isTargetMode;
        if (targetLosLine) targetLosLine.show = isTargetMode;

        if (isTargetMode && data.target_ecef) {
            targetEcef = new Cesium.Cartesian3(data.target_ecef[0], data.target_ecef[1], data.target_ecef[2]);
        } else {
            targetEcef = null;
        }

        document.getElementById('telemetryDetailsContent').innerHTML = html;
        updateCharts(data);

    } catch (error) {
        console.error("updateTelemetryDisplay error:", error);
    }
}
