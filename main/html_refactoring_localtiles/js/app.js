// ================== Application Entry Point ==================

function initialize() {
    initCesium();
    initCharts();
    setupKeyboardControls();
    setupAttitudeControlButtons();
    connectWebSocket();
    updateAttitudeControlPanelVisibility();
    updateModeButtonsUI(currentControlMode);
    console.log("Application initialized");
}

document.addEventListener('DOMContentLoaded', initialize);
