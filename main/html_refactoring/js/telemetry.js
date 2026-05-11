// ================== Telemetry UI ==================

function toggleTelemetryDetails() {
    telemetryExpanded = !telemetryExpanded;
    const details = document.getElementById('telemetryDetails');
    const icon    = document.getElementById('telemetryToggleIcon');
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

        let altitude = '--', lat = '--', lon = '--';
        if (data.position_ecef) {
            try {
                const lla = ecefToLla(
                    data.position_ecef[0], data.position_ecef[1], data.position_ecef[2]
                );
                altitude = formatNumber(lla.altitude / 1000, 1) + ' km';
                lat      = formatNumber(lla.latitude,  2) + '\u00B0';
                lon      = formatNumber(lla.longitude, 2) + '\u00B0';
            } catch (e) { }
        }

        document.getElementById('summaryMode').textContent =
            data.ctrl_mode !== undefined
                ? `${data.ctrl_mode}: ${(data.ctrl_mode_name || MODE_NAMES[data.ctrl_mode]).substring(0, 12)}`
                : '--';
        document.getElementById('summaryTime').textContent =
            data.time !== undefined ? formatNumber(data.time, 0) + 's' : '--';

        let html = `
            <div class="telemetry-section" style="margin-top:0; padding-top:0; border-top:none;">
                <div class="section-title">TIME</div>
                <div>Sim Time: ${formatNumber(data.time, 1)} s</div>
                <div>Date: ${data.simDate || 'N/A'}</div>
            </div>
        `;

        if (data.ctrl_mode !== undefined) {
            html += `<div class="mode-indicator mode-${data.ctrl_mode}">
                ${data.ctrl_mode} - ${data.ctrl_mode_name || MODE_NAMES[data.ctrl_mode]}
            </div>`;
        }

        if (data.position_ecef) {
            html += `<div class="telemetry-section"><div class="section-title">POSITION</div>
                <div style="display:flex;justify-content:space-between;"><span>Lat:</span><span style="color:white">${lat}</span></div>
                <div style="display:flex;justify-content:space-between;"><span>Lon:</span><span style="color:white">${lon}</span></div>
                <div style="display:flex;justify-content:space-between;"><span>Alt:</span><span style="color:white">${altitude}</span></div>
            </div>`;
        }

        if (data.pointing_error_deg !== undefined) {
            const c = data.pointing_error_deg < 1 ? '#4caf50'
                    : data.pointing_error_deg < 5 ? '#ff9800' : '#f44336';
            html += `<div class="telemetry-section"><div class="section-title">POINTING ERROR</div>
                <div style="font-size:18px;font-weight:bold;color:${c};text-align:right;">
                    ${formatNumber(data.pointing_error_deg, 3)}\u00B0
                </div></div>`;
        }

        if (data.wheel_speeds_rpm) {
            html += `<div class="telemetry-section"><div class="section-title">WHEEL SPEED (rpm)</div>
                <div style="display:flex;justify-content:space-between;"><span>X:</span><span style="color:white">${formatNumber(data.wheel_speeds_rpm[0], 1)}</span></div>
                <div style="display:flex;justify-content:space-between;"><span>Y:</span><span style="color:white">${formatNumber(data.wheel_speeds_rpm[1], 1)}</span></div>
                <div style="display:flex;justify-content:space-between;"><span>Z:</span><span style="color:white">${formatNumber(data.wheel_speeds_rpm[2], 1)}</span></div>
            </div>`;
        }

        if (data.ctrl_mode === 7 && data.target_name) {
            const onaColor = data.off_nadir_deg < 30 ? '#4caf50'
                           : data.off_nadir_deg < 60 ? '#ff9800' : '#f44336';
            html += `<div class="telemetry-section">
                <div class="section-title" style="color:#e879f9;">\uD83C\uDFAF TARGET: ${data.target_name}</div>
                <div style="display:flex;justify-content:space-between;"><span>LOS Distance:</span><span style="color:white">${formatNumber(data.los_distance_km, 1)} km</span></div>
                <div style="display:flex;justify-content:space-between;"><span>Off-Nadir:</span><span style="color:${onaColor}">${formatNumber(data.off_nadir_deg, 1)}\u00B0</span></div>
            </div>`;
        }

        const isTargetMode = (data.ctrl_mode === 7);
        if (targetMarker)  targetMarker.show  = isTargetMode;
        if (targetLosLine) targetLosLine.show = isTargetMode;

        if (isTargetMode && data.target_ecef) {
            targetEcef = new Cesium.Cartesian3(
                data.target_ecef[0], data.target_ecef[1], data.target_ecef[2]
            );
        } else {
            targetEcef = null;
        }

        document.getElementById('telemetryDetailsContent').innerHTML = html;
        updateCharts(data);

    } catch (error) {
        console.error("updateTelemetryDisplay error:", error);
    }
}

// ================== Layer UI ==================

let targetLayerVisible   = true;
let targetHeadingVisible = false;

function initLayerUI() {}

// Sat Only / Sat+All 토글 
function setTargetLayerMode(mode) {
    const btnSatOnly = document.getElementById('btnSatOnly');
    const btnSatAll  = document.getElementById('btnSatAll');
    const chk        = document.getElementById('chkTargets');

    if (mode === 'sat_only') {
        targetLayerVisible = false;
        if (targetDataSource) targetDataSource.show = false;
        if (btnSatOnly) btnSatOnly.style.background = '#3b82f6';
        if (btnSatAll)  btnSatAll.style.background  = '#555';
        if (chk) chk.checked = false;
        console.log('[Display] Satellite Only');
    } else {
        targetLayerVisible = true;
        if (targetDataSource) targetDataSource.show = true;
        if (btnSatOnly) btnSatOnly.style.background = '#555';
        if (btnSatAll)  btnSatAll.style.background  = '#10b981';
        if (chk) chk.checked = true;
        console.log('[Display] Satellite + All Targets');
    }
}

// toggleTargetLayer
function toggleTargetLayer() {
    targetLayerVisible = !targetLayerVisible;
    if (targetDataSource) targetDataSource.show = targetLayerVisible;

    const btnSatOnly = document.getElementById('btnSatOnly');
    const btnSatAll  = document.getElementById('btnSatAll');
    if (targetLayerVisible) {
        if (btnSatOnly) btnSatOnly.style.background = '#555';
        if (btnSatAll)  btnSatAll.style.background  = '#10b981';
    } else {
        if (btnSatOnly) btnSatOnly.style.background = '#3b82f6';
        if (btnSatAll)  btnSatAll.style.background  = '#555';
    }
    const chk = document.getElementById('chkTargets');
    if (chk) chk.checked = targetLayerVisible;
}

function onTargetsCheckbox(checked) {
    targetLayerVisible = checked;
    if (targetDataSource) targetDataSource.show = checked;

    const btnSatOnly = document.getElementById('btnSatOnly');
    const btnSatAll  = document.getElementById('btnSatAll');
    if (checked) {
        if (btnSatOnly) btnSatOnly.style.background = '#555';
        if (btnSatAll)  btnSatAll.style.background  = '#10b981';
    } else {
        if (btnSatOnly) btnSatOnly.style.background = '#3b82f6';
        if (btnSatAll)  btnSatAll.style.background  = '#555';
    }
}

// Heading 방향 표시 핸들러
function onHeadingCheckbox(checked) {
    targetHeadingVisible = checked;
    if (!targetDataSource) return;
    Object.values(targetEntityMap).forEach(entity => {
        if (entity._headingLine) entity._headingLine.show = checked;
    });
}

// Target Layer UI 카운터/윈도우 업데이트
function _updateTargetLayerUI(count, sampleWindow) {
    const countEl = document.getElementById('targetCount');
    if (countEl) countEl.textContent = count;

    const winEl = document.getElementById('targetSampleWindow');
    if (winEl) {
        winEl.textContent = sampleWindow.length
            ? `[${sampleWindow.map(v => v.toFixed(1)).join(', ')}]`
            : '--';
    }
}