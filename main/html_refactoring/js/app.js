// ================== Application Entry Point ==================
function initialize() {
    initCesium();
    // initShipAircraftEntities();   
    initCharts();
    setupKeyboardControls();
    setupAttitudeControlButtons();
    connectWebSocket();
    updateAttitudeControlPanelVisibility();
    updateModeButtonsUI(currentControlMode);
    initLayerUI();
    startShipAircraftSimLoop();
    console.log("Application initialized");
}
document.addEventListener('DOMContentLoaded', initialize);
