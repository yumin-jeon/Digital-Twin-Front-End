// ================== Chart.js Real-time Graphs ==================

function initCharts() {
    const chartConfig = {
        type: 'line',
        options: {
            responsive: true, maintainAspectRatio: false, animation: false,
            interaction: { mode: 'none' },
            plugins: { legend: { display: false }, tooltip: { enabled: false } },
            scales: {
                x: { display: false, type: 'linear', min: 0 },
                y: {
                    display: true, position: 'right',
                    grid: { color: 'rgba(255, 255, 255, 0.05)', drawBorder: false, tickLength: 0 },
                    ticks: { color: '#475569', font: { size: 9, family: 'monospace' }, maxTicksLimit: 3, padding: 5 },
                    border: { display: false }
                }
            },
            elements: { point: { radius: 0, hitRadius: 0 }, line: { borderWidth: 1.5, tension: 0.4 } }
        }
    };

    function createDatasets(ctx) {
        const gradientCmd = ctx.createLinearGradient(0, 0, 0, 80);
        gradientCmd.addColorStop(0, 'rgba(59, 130, 246, 0.3)');
        gradientCmd.addColorStop(1, 'rgba(59, 130, 246, 0.0)');
        const gradientAct = ctx.createLinearGradient(0, 0, 0, 80);
        gradientAct.addColorStop(0, 'rgba(239, 68, 68, 0.3)');
        gradientAct.addColorStop(1, 'rgba(239, 68, 68, 0.0)');

        return {
            datasets: [
                { label: 'Command', data: [], borderColor: '#3b82f6', backgroundColor: gradientCmd, fill: true, order: 2 },
                { label: 'Actual', data: [], borderColor: '#ef4444', backgroundColor: gradientAct, fill: true, order: 1 }
            ]
        };
    }

    const chartIds = {
        rollRate: 'chartRollRate', pitchRate: 'chartPitchRate', yawRate: 'chartYawRate',
        rollAtt: 'chartRollAtt', pitchAtt: 'chartPitchAtt', yawAtt: 'chartYawAtt'
    };

    for (const [key, canvasId] of Object.entries(chartIds)) {
        const canvas = document.getElementById(canvasId);
        if (canvas) {
            const ctx = canvas.getContext('2d');
            charts[key] = new Chart(ctx, { ...chartConfig, data: createDatasets(ctx) });
        }
    }
    console.log("Charts initialized");
}

function updateCharts(data) {
    if (!data.time) return;

    const time = data.time;
    const angVel = data.angularVelocity || [0, 0, 0];
    const targetRates = data.targetRates || [0, 0, 0];
    const eulerActual = data.euler321_actual_deg || [0, 0, 0];
    const eulerCmd = data.euler321_cmd_deg || [0, 0, 0];

    // Convert rad/s to deg/s
    const rollRateAct = angVel[0] * 180 / Math.PI;
    const pitchRateAct = angVel[1] * 180 / Math.PI;
    const yawRateAct = angVel[2] * 180 / Math.PI;

    // Push new data
    graphData.time.push(time);
    graphData.rollRateCmd.push(targetRates[0]); graphData.rollRateAct.push(rollRateAct);
    graphData.pitchRateCmd.push(targetRates[1]); graphData.pitchRateAct.push(pitchRateAct);
    graphData.yawRateCmd.push(targetRates[2]); graphData.yawRateAct.push(yawRateAct);
    graphData.rollAttCmd.push(eulerCmd[0]); graphData.rollAttAct.push(eulerActual[0]);
    graphData.pitchAttCmd.push(eulerCmd[1]); graphData.pitchAttAct.push(eulerActual[1]);
    graphData.yawAttCmd.push(eulerCmd[2]); graphData.yawAttAct.push(eulerActual[2]);

    // Trim to max points
    while (graphData.time.length > MAX_DATA_POINTS) {
        graphData.time.shift();
        graphData.rollRateCmd.shift(); graphData.rollRateAct.shift();
        graphData.pitchRateCmd.shift(); graphData.pitchRateAct.shift();
        graphData.yawRateCmd.shift(); graphData.yawRateAct.shift();
        graphData.rollAttCmd.shift(); graphData.rollAttAct.shift();
        graphData.pitchAttCmd.shift(); graphData.pitchAttAct.shift();
        graphData.yawAttCmd.shift(); graphData.yawAttAct.shift();
    }

    // Update value displays
    const setVal = (id, val) => {
        const el = document.getElementById(id);
        if (el) el.textContent = formatNumber(val, 2);
    };
    setVal('valRollCmd', targetRates[0]); setVal('valRollAct', rollRateAct);
    setVal('valPitchCmd', targetRates[1]); setVal('valPitchAct', pitchRateAct);
    setVal('valYawCmd', targetRates[2]); setVal('valYawAct', yawRateAct);
    setVal('valRollAttCmd', eulerCmd[0]); setVal('valRollAttAct', eulerActual[0]);
    setVal('valPitchAttCmd', eulerCmd[1]); setVal('valPitchAttAct', eulerActual[1]);
    setVal('valYawAttCmd', eulerCmd[2]); setVal('valYawAttAct', eulerActual[2]);

    // Update chart datasets
    const timeData = graphData.time;
    const minTime = timeData[0] || 0;
    const maxTime = timeData[timeData.length - 1] || 100;

    function updateSingleChart(chart, cmdData, actData) {
        if (!chart) return;
        chart.data.datasets[0].data = timeData.map((t, i) => ({ x: t, y: cmdData[i] }));
        chart.data.datasets[1].data = timeData.map((t, i) => ({ x: t, y: actData[i] }));
        chart.options.scales.x.min = minTime;
        chart.options.scales.x.max = maxTime;
        chart.update('none');
    }

    updateSingleChart(charts.rollRate, graphData.rollRateCmd, graphData.rollRateAct);
    updateSingleChart(charts.pitchRate, graphData.pitchRateCmd, graphData.pitchRateAct);
    updateSingleChart(charts.yawRate, graphData.yawRateCmd, graphData.yawRateAct);
    updateSingleChart(charts.rollAtt, graphData.rollAttCmd, graphData.rollAttAct);
    updateSingleChart(charts.pitchAtt, graphData.pitchAttCmd, graphData.pitchAttAct);
    updateSingleChart(charts.yawAtt, graphData.yawAttCmd, graphData.yawAttAct);
}
