// ================== Application Entry Point ==================

function initialize() {
    initCesium();
    initCharts();
    setupKeyboardControls();
    setupAttitudeControlButtons();
    connectWebSocket();
    updateAttitudeControlPanelVisibility();
    updateModeButtonsUI(currentControlMode);
    initProjectile(); 
    console.log("Application initialized");
}

document.addEventListener('DOMContentLoaded', initialize);
