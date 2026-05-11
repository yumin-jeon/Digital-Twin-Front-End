// ================== Control Mode UI ==================

function toggleModePanel() {
    isModePanelExpanded = !isModePanelExpanded;
    const list = document.getElementById('modeList');
    const icon = document.getElementById('modeToggleIcon');
    const header = document.getElementById('modeHeader');

    if (isModePanelExpanded) {
        list.classList.add('expanded');
        icon.classList.add('expanded');
        header.classList.add('expanded');
    } else {
        list.classList.remove('expanded');
        icon.classList.remove('expanded');
        header.classList.remove('expanded');
    }
}

function setControlMode(mode) {
    console.log('Requested mode change to:', MODE_NAMES[mode]);
    updateModeButtonsUI(mode);

    if (isModePanelExpanded) {
        toggleModePanel();
    }

    if (isConnected) {
        socket.send(JSON.stringify({
            command: 'set_mode',
            ctrl_mode: mode
        }));
    }
}

function updateModeButtonsUI(mode) {
    for (let i = 0; i <= 7; i++) {
        const btn = document.getElementById('mode' + i);
        if (btn) {
            btn.classList.remove('active');
            if (i === mode) btn.classList.add('active');
        }
    }
    currentControlMode = mode;
    const headerText = document.getElementById('currentModeText');
    if (headerText) {
        headerText.textContent = `${mode}: ${MODE_NAMES[mode]}`;
    }
    updateAttitudeControlPanelVisibility();
}

function updateBackendModeDisplay(mode, modeName) {
    backendControlMode = mode;
    updateModeButtonsUI(mode);
}

// ================== Attitude Control (WASD Pad) ==================

function activateButton(id) {
    const btn = document.getElementById(id);
    if (btn) btn.classList.add('active');
}

function deactivateButton(id) {
    const btn = document.getElementById(id);
    if (btn) btn.classList.remove('active');
}

function sendAttitudeCommand(command) {
    if (!isConnected || currentControlMode !== 4) return;
    socket.send(JSON.stringify({ command: command }));
}

function updateAttitudeControlPanelVisibility() {
    const panel = document.getElementById('attitudeControlPanel');
    if (panel) panel.classList.toggle('visible', currentControlMode === 4);
}

function setupAttitudeControlButtons() {
    document.querySelectorAll('.dpad-btn-group, .roll-btn').forEach(btn => {
        const cmd = btn.dataset.command;
        if (!cmd) return;
        const startHandler = (e) => { e.preventDefault(); btn.classList.add('active'); sendAttitudeCommand(cmd); };
        const endHandler = () => { btn.classList.remove('active'); };
        btn.addEventListener('mousedown', startHandler);
        btn.addEventListener('mouseup', endHandler);
        btn.addEventListener('mouseleave', endHandler);
        btn.addEventListener('touchstart', startHandler, { passive: false });
        btn.addEventListener('touchend', endHandler);
        btn.addEventListener('touchcancel', endHandler);
    });
}

// ================== Keyboard Controls ==================

function setupKeyboardControls() {
    document.addEventListener('keydown', function (event) {
        // Camera mode switching (F1-F4)
        if (['F1', 'F2', 'F3', 'F4'].includes(event.code)) event.preventDefault();
        if (event.code === 'F1') switchCameraMode(0);
        if (event.code === 'F2') switchCameraMode(1);
        if (event.code === 'F3') switchCameraMode(2);
        if (event.code === 'F4') switchCameraMode(3);

        // Control mode switching (0-7)
        if (['Digit0', 'Numpad0'].includes(event.code)) setControlMode(0);
        if (['Digit1', 'Numpad1'].includes(event.code)) setControlMode(1);
        if (['Digit2', 'Numpad2'].includes(event.code)) setControlMode(2);
        if (['Digit3', 'Numpad3'].includes(event.code)) setControlMode(3);
        if (['Digit4', 'Numpad4'].includes(event.code)) setControlMode(4);
        if (['Digit5', 'Numpad5'].includes(event.code)) setControlMode(5);
        if (['Digit7', 'Numpad7'].includes(event.code)) setControlMode(7);

        // Attitude commands (only in Interactive mode)
        if (!isConnected || currentControlMode !== 4) return;
        let command = '';
        switch (event.code) {
            case 'KeyW': command = 'increase_pitch'; break;
            case 'KeyS': command = 'decrease_pitch'; break;
            case 'KeyA': command = 'yaw_left'; break;
            case 'KeyD': command = 'yaw_right'; break;
            case 'KeyQ': command = 'increase_roll'; break;
            case 'KeyE': command = 'decrease_roll'; break;
            case 'Space': command = 'stop_rotation'; event.preventDefault(); break;
        }
        const btnId = KEY_TO_BUTTON_ID[event.code];
        if (command && btnId) {
            activateButton(btnId);
            socket.send(JSON.stringify({ command: command }));
        }
    });

    document.addEventListener('keyup', function (event) {
        const btnId = KEY_TO_BUTTON_ID[event.code];
        if (btnId) deactivateButton(btnId);
    });
}
