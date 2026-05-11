%% main_InteractiveSatControlv6.m
%% script for solving rigid body dynamics and kinematics with closed loop control
%% Author: Zizung Yoon
%% Modified for WebSocket communication with Cesium with ECI to ECEF conversion
%% v6: Added all control modes from quatDynClosedLoop.m with Cesium mode switching
close all
clear all
display('Run simulation with Cesium visualization via Python WebSocket');
display('v6: Multi-Mode Support (Modes 0-5 from quatDynClosedLoop.m)');

% Setup file paths for command input and telemetry output
% ===== JSON 파일 경로를 repoRoot/data로 고정 =====
mainDir  = fileparts(mfilename('fullpath'));   % .../main
repoRoot = fileparts(mainDir);                 % repo root
dataDir  = fullfile(repoRoot, 'data');
if ~exist(dataDir, 'dir')
    mkdir(dataDir);
end
commandFile   = fullfile(dataDir, 'command_in.json');
telemetryFile = fullfile(dataDir, 'telemetry_out.json');
targetFile    = fullfile(dataDir, 'target_out.json');
unifiedTargetDir = fullfile(dataDir, 'trajectory', 'unified');

% Clear or create initial files
fid = fopen(commandFile, 'w');
fprintf(fid, '{"command": ""}');
fclose(fid);
fid = fopen(telemetryFile, 'w');
fprintf(fid, '{"initialized": true}');
fclose(fid);
fid = fopen(targetFile, 'w');
fprintf(fid, '{"type": "target_update", "initialized": true, "target_count": 0, "targets": []}');
fclose(fid);

%% Constants
mu_earth = 398600.4418;       % [km^3/s^2]
R_earth = 6378.137;           % [km] Earth equatorial radius
J2 = 1.08262668e-3;           % [-] Earth's J2 coefficient
omegaEarth = 7.2921159e-5;    % [rad/s] Earth's rotation rate

%% Simulation date and time
% Set initial simulation date (J2000 epoch by default)
simStart = datetime(2000, 1, 1, 12, 0, 0); % J2000 epoch
simTime = 0; % Initialize simulation time in seconds

%% Define orbital elements (제주도 통과 최적화)
a     = 7000;              % SMA [km]
e     = 0.01;              % eccentricity
i     = deg2rad(98);       % inclination [rad]
RAAN  = deg2rad(130.8);    % RAAn [rad] - 제주도 중앙에 궤도면을 맞추기 위해 132에서 130.8로 수정
omega = deg2rad(0);        % Arg. of Perigee [rad]
theta = deg2rad(28);       % true anomaly [rad] - 제주도 살짝 아래에서 시작하도록 20에서 28로 수정

% Get state vector
[rsat_eci0, vsat_eci0] = kepler2rv(a, e, i, RAAN, omega, theta, mu_earth);

%% satellite property
I_b=[5 0 0; 0 6 0; 0 0 7]; %moi satellite [kgm^2]
I_rw=[.01 0 0; 0 .01 0; 0 0 .01]; %moi wheel [kgm^2]

%% initial condition
q0 = [0.7071; 0.7071; 0; 0];   % sat attitude w.r.t inertial frame (q0 q1 q2 q3)
om_sat0 = deg2rad([0; 0; 0]);  % sat angular rate [rad/s]
om_rw0 = convangvel([0;0;0],'rpm','rad/s'); % wheel rate [rad/s]
x0 = [om_sat0; q0; om_rw0; rsat_eci0; vsat_eci0]; % initial state vector
T_ext=[0; 0; 0]; % external torque [Nms]
T_rw=[0; 0; 0]; % wheel torque in body frame [Nms]

%% simulation setting
tstep= 1;      % step for ode solver [s]
te = 36000;    % sim end time[s]

%% =========================================================================
qCMD_ECI2SAT = [1;0;0;0];           % target quaternion from ECI to commanded SAT frame
qCMD_LVLH2SAT = [1;0;0;0]; % quaternion from LVLH to CMD (offset)

global omTrgt_sat
omTrgt_sat = deg2rad([0; 0; 0]);    % target angular rate of sat for rate control

global omTrgt_eci
omTrgt_eci = deg2rad([0; 0; 0]);    % target angular rate in ECI frame for headless mode

ctrl_mode = 7;  % 
                % 0: no control
                % 1: rate damping (ctrlDamp)
                % 2: Inertial Pointing Mode (IPM) - quaternion feedback
                % 3: Nadir Pointing Mode (NPM) - quaternion feedback
                % 4: Interactive Mode - angular rate control
                % 5: Momentum Bias
                % 6: Headless Mode - ECI frame rate control
                % 7: Target Pointing - Ground target tracking (Jeju-do)

% 제어 모드 이름 (텔레메트리 출력용)
ctrl_mode_names = {'No Control', 'Rate Damping', 'Inertial Pointing', ...
                   'Nadir Pointing', 'Interactive', 'Momentum Bias', ...
                   'Headless', 'Target Pointing'};

disp(' ');
disp('Control Modes:');
disp('  0: No Control      - Free tumbling');
disp('  1: Rate Damping    - Reduce angular rates');
disp('  2: Inertial Point  - Fixed inertial target (IPM)');
disp('  3: Nadir Pointing  - Point to Earth center (NPM)');
disp('  4: Interactive     - Manual control (W/S/A/D/Q/E)');
disp('  5: Momentum Bias   - Bias wheel stabilization');
disp('  6: Headless        - ECI frame manual control (drone headless mode)');
disp('  7: Target Pointing - Track ground target (Jeju-do)');
disp(' ');
fprintf('Initial Mode: %d - %s\n', ctrl_mode, ctrl_mode_names{ctrl_mode+1});

%% Target Layer unified trajectory data
targets = loadTargetTrajectories(unifiedTargetDir);
targetSampleOffsets = 0:2;
targetPacket = buildTargetPacket(targets, 0, targetSampleOffsets);
lastTargetLogTime = -inf;

%% =========================================================================
%% pre allocation
tc = zeros(1, te + 1);                 % time history
xs  = zeros(length(x0), te + 1);       % state vector history

%% 오차 쿼터니언 기록용
qE = zeros(4, te + 1);

%%% === cmd / actual 각속도 & 자세 기록용 ===
om_cmd_hist   = zeros(3, te + 1);      % [rad/s]
om_act_hist   = zeros(3, te + 1);      % [rad/s]
euler_cmd_deg = zeros(3, te + 1);      % [deg] (321: roll, pitch, yaw)
euler_act_deg = zeros(3, te + 1);      % [deg]
q_cmd = q0;                            % "명령 자세" 쿼터니언 초기값

%% Initializing timestamp for file reading
lastCommandCheck = 0;
checkInterval = 0.5; % Check for new commands every 0.5 seconds

%% control loop
odeopt = odeset('RelTol', 1e-6, 'AbsTol', 1e-6, 'InitialStep', tstep, 'MaxStep', tstep);
t = 0;
xs(:,1) = x0; % initial condition
tc(1)   = 0;

%% =========================================================================
%% 실시간 그래프 초기화
%% =========================================================================
% 그래프 1: 각속도 (deg/s) - 명령 vs 실제
fig_rate = figure('Name', 'Angular velocity (deg/s): ', 'Position', [50, 400, 700, 500]);

subplot(3,1,1);
hold on; grid on;
h_roll_cmd = animatedline('Color', 'b', 'LineWidth', 1.5, 'DisplayName', 'Cmd rate');
h_roll_act = animatedline('Color', 'r', 'LineWidth', 1.2, 'DisplayName', 'Actual rate');
ylabel('Roll ω (deg/s)');
title('Roll Rate');
legend('Location', 'northeast');

subplot(3,1,2);
hold on; grid on;
h_pitch_cmd = animatedline('Color', 'b', 'LineWidth', 1.5, 'DisplayName', 'Cmd rate');
h_pitch_act = animatedline('Color', 'r', 'LineWidth', 1.2, 'DisplayName', 'Actual rate');
ylabel('Pitch ω (deg/s)');
title('Pitch Rate');
legend('Location', 'northeast');

subplot(3,1,3);
hold on; grid on;
h_yaw_cmd = animatedline('Color', 'b', 'LineWidth', 1.5, 'DisplayName', 'Cmd rate');
h_yaw_act = animatedline('Color', 'r', 'LineWidth', 1.2, 'DisplayName', 'Actual rate');
ylabel('Yaw ω (deg/s)');
xlabel('Time (s)');
title('Yaw Rate');
legend('Location', 'northeast');

sgtitle('Angular velocity (deg/s)', 'FontSize', 14, 'FontWeight', 'bold');

% 그래프 2: 자세 (Euler 321, deg) - 명령 vs 실제
fig_att = figure('Name', 'Attitude (Euler 321, deg)', 'Position', [760, 400, 700, 500]);

subplot(3,1,1);
hold on; grid on;
h_phi_cmd = animatedline('Color', 'b', 'LineWidth', 1.5, 'DisplayName', 'Command');
h_phi_act = animatedline('Color', 'r', 'LineWidth', 1.2, 'DisplayName', 'Actual');
ylabel('Roll φ (deg)');
title('Roll(φ)');
legend('Location', 'northeast');

subplot(3,1,2);
hold on; grid on;
h_theta_cmd = animatedline('Color', 'b', 'LineWidth', 1.5, 'DisplayName', 'Command');
h_theta_act = animatedline('Color', 'r', 'LineWidth', 1.2, 'DisplayName', 'Actual');
ylabel('Pitch θ (deg)');
title('Pitch(θ)');
legend('Location', 'northeast');

subplot(3,1,3);
hold on; grid on;
h_psi_cmd = animatedline('Color', 'b', 'LineWidth', 1.5, 'DisplayName', 'Command');
h_psi_act = animatedline('Color', 'r', 'LineWidth', 1.2, 'DisplayName', 'Actual');
ylabel('Yaw ψ (deg)');
xlabel('Time (s)');
title('Yaw(ψ)');
legend('Location', 'northeast');

sgtitle('Attitude (Euler 321, deg)', 'FontSize', 14, 'FontWeight', 'bold');

% 실시간 그래프 업데이트 간격 설정
plotUpdateInterval = 1;  % 매 N 스텝마다 그래프 업데이트
enableMatlabPlots = true;
plotWarningShown = false;

disp('Starting simulation loop...');
disp('Press Ctrl+C to stop the simulation');
disp('Commands from Cesium: Q/E for roll, W/S for pitch, A/D for yaw, Space to stop rotation');
disp('Mode change: Number keys 0-7 in Cesium');
disp('Mode 4 (Interactive): commands in satellite body frame');
disp('Mode 6 (Headless):    commands in ECI inertial frame');
disp('Mode 7 (Target):      auto-track Jeju-do ground target');

for n = 1:te
    % Solve ODE for this timestep
    [ts, y] = ode45(@(t,x)rhs_matlab(t,x, I_b, I_rw, T_ext, T_rw, mu_earth, J2, R_earth), ...
                    [t t+tstep], xs(:,n), odeopt);
    
    t = ts(end);                 % last time in this step
    xs(:,n+1) = y(end,:)';       % updated state
    tc(n+1)   = t;
    simTime = t;                 % Update simulation time in seconds
    k = n+1;
    
    % Update simulation date
    currentSimTime = simStart + seconds(simTime);
    targetPacket = buildTargetPacket(targets, simTime, targetSampleOffsets);
    if simTime - lastTargetLogTime >= 10
        fprintf('[TargetLayer] t=%6.0fs target_out: %d targets, window=%s\n', ...
                simTime, targetPacket.target_count, mat2str(targetPacket.sample_window));
        lastTargetLogTime = simTime;
    end

    % ===== 현재 스텝 물리량 =====
    om_sat    = xs(1:3,   k);
    q_SAT2ECI = xs(4:7,   k);   % (가정) SAT->ECI
    om_rw     = xs(8:10,  k);
    r_sat     = xs(11:13, k);
    v_sat     = xs(14:16, k);

    %% =========================================================================
    switch ctrl_mode
        case {0, 4, 6}  % No control / Interactive / Headless - no external damping
            T_ext = [0;0;0];
        otherwise    % 나머지 모드(1,2,3,5,7) - damping 적용
            T_ext = ctrlDamp(xs(1:3,n+1));
    end
    
    %% =========================================================================
    if (t - lastCommandCheck) >= checkInterval
        try
            cmd = '';
            new_ctrl_mode = -1;  % [v6 추가]
            
            if exist(commandFile, 'file')
                jsonData = jsondecode(fileread(commandFile));
                
                % 명령어 읽기
                if isfield(jsonData, 'command')
                    cmd = jsonData.command;
                end
                
                % [v6 추가] 모드 변경 읽기
                if isfield(jsonData, 'ctrl_mode')
                    new_ctrl_mode = jsonData.ctrl_mode;
                end
                
                % Clear the command after reading it
                fid = fopen(commandFile, 'w');
                fprintf(fid, '{"command": ""}');
                fclose(fid);
            end
            lastCommandCheck = t;
        catch e
            disp(['Error reading command file: ', e.message]);
            cmd = '';
            new_ctrl_mode = -1;
        end
    else
        cmd = '';
        new_ctrl_mode = -1;
    end

    %% =========================================================================
    if new_ctrl_mode >= 0 && new_ctrl_mode <= 7 && new_ctrl_mode ~= ctrl_mode
        old_mode = ctrl_mode;
        ctrl_mode = new_ctrl_mode;
        fprintf('[t=%6.0fs] Mode changed: %d (%s) -> %d (%s)\n', ...
                t, old_mode, ctrl_mode_names{old_mode+1}, ...
                ctrl_mode, ctrl_mode_names{ctrl_mode+1});
        
        % 모드 변경 시 target rate 초기화 (Interactive/Headless 모드가 아닐 때)
        if ctrl_mode ~= 4 && ctrl_mode ~= 6
            omTrgt_sat = [0; 0; 0];
            omTrgt_eci = [0; 0; 0];
        end
        % Headless 모드 진입 시 ECI 목표 초기화
        if ctrl_mode == 6
            omTrgt_eci = [0; 0; 0];
        end
        % Interactive 모드 진입 시 body 목표 초기화
        if ctrl_mode == 4
            omTrgt_sat = [0; 0; 0];
        end
    end

    %% =========================================================================
    if ~isempty(cmd) && ctrl_mode == 4
        switch cmd
            case 'increase_roll'
                omTrgt_sat(1) = omTrgt_sat(1) + deg2rad(0.1);
                disp('Command received: Increase roll');
            case 'decrease_roll'
                omTrgt_sat(1) = omTrgt_sat(1) - deg2rad(0.1);
                disp('Command received: Decrease roll');
            case 'increase_pitch'
                omTrgt_sat(2) = omTrgt_sat(2) + deg2rad(0.1);
                disp('Command received: Increase pitch');
            case 'decrease_pitch'
                omTrgt_sat(2) = omTrgt_sat(2) - deg2rad(0.1);
                disp('Command received: Decrease pitch');
            case 'yaw_left'
                omTrgt_sat(3) = omTrgt_sat(3) + deg2rad(0.1);
                disp('Command received: Yaw left');
            case 'yaw_right'
                omTrgt_sat(3) = omTrgt_sat(3) - deg2rad(0.1);
                disp('Command received: Yaw right');
            case 'stop_rotation'
                omTrgt_sat(:) = 0;
                disp('Command received: Stop rotation');
            otherwise
                if ~isempty(cmd)
                    disp(['Unrecognized command: ', cmd]);
                end
        end
    end

    %% ===== Headless Mode (6): 동일 키 입력이지만 ECI 프레임 기준 =====
    if ~isempty(cmd) && ctrl_mode == 6
        switch cmd
            case 'increase_roll'    % ECI X축 양방향 회전
                omTrgt_eci(1) = omTrgt_eci(1) + deg2rad(0.1);
                disp('[Headless] ECI X+ rotation increased');
            case 'decrease_roll'    % ECI X축 음방향 회전
                omTrgt_eci(1) = omTrgt_eci(1) - deg2rad(0.1);
                disp('[Headless] ECI X- rotation increased');
            case 'increase_pitch'   % ECI Y축 양방향 회전
                omTrgt_eci(2) = omTrgt_eci(2) + deg2rad(0.1);
                disp('[Headless] ECI Y+ rotation increased');
            case 'decrease_pitch'   % ECI Y축 음방향 회전
                omTrgt_eci(2) = omTrgt_eci(2) - deg2rad(0.1);
                disp('[Headless] ECI Y- rotation increased');
            case 'yaw_left'         % ECI Z축 양방향 회전
                omTrgt_eci(3) = omTrgt_eci(3) + deg2rad(0.1);
                disp('[Headless] ECI Z+ rotation increased');
            case 'yaw_right'        % ECI Z축 음방향 회전
                omTrgt_eci(3) = omTrgt_eci(3) - deg2rad(0.1);
                disp('[Headless] ECI Z- rotation increased');
            case 'stop_rotation'
                omTrgt_eci(:) = 0;
                disp('[Headless] Stop all ECI rotation');
            otherwise
                if ~isempty(cmd)
                    disp(['Unrecognized command: ', cmd]);
                end
        end
    end

    %% =========================================================================
    switch ctrl_mode
        case 0
            t_ctrl = [0;0;0];
        case 1
            t_ctrl = ctrlDamp(om_sat) * 5;
        case 2  % Inertial Pointing
            qErr = quatMult(qCMD_ECI2SAT, q_SAT2ECI);
            qErr = qErr(:);
            qErr = qErr / norm(qErr);

            % ===== error quaternion scalar를 항상 +로(최단회전) =====
            if qErr(1) < 0
                qErr = -qErr;
            end
            qE(:,k) = qErr;
            
            t_ctrl = ctrlRwQuat(I_b, qErr, om_sat);
            
        case 3  % Nadir Pointing
            z_hat = -r_sat / norm(r_sat);
            y_hat = -cross(r_sat, v_sat);
            y_hat = y_hat / norm(y_hat);
            x_hat = cross(y_hat, z_hat);

            R_eci2lvlh = [x_hat, y_hat, z_hat]';
            
            q_ECI2LVLH = dcm2quat(R_eci2lvlh);
            q_ECI2LVLH = q_ECI2LVLH(:);
            
            % (LVLH->CMD) ⊗ (ECI->LVLH) = ECI->CMD(목표)
            qTrgt_nadir = quatMult(qCMD_LVLH2SAT, q_ECI2LVLH);
            qTrgt_nadir = qTrgt_nadir(:);
            qTrgt_nadir = qTrgt_nadir / norm(qTrgt_nadir);
            
            % error: (ECI->CMD) ⊗ (SAT->ECI) = SAT->CMD
            qErr = quatMult(qTrgt_nadir, q_SAT2ECI);
            qErr = qErr(:);
            qErr = qErr / norm(qErr);

            % ===== error quaternion scalar를 항상 +로(최단회전) =====
            if qErr(1) < 0
                qErr = -qErr;
            end
            qE(:,k) = qErr;
            
            % =========================
            % Desired angular rate (LVLH/CMD wrt ECI)
            % =========================
            % Orbit angular velocity vector in ECI:  ω = (r×v)/|r|^2
            h_vec = cross(r_sat, v_sat);                 % [km^2/s]
            om_LVLH_eci = h_vec / (norm(r_sat)^2);       % [rad/s]  (units -> 1/s)
            
            % Express desired omega in SAT(body) frame
            % q_SAT2ECI : SAT -> ECI  이므로, ECI -> SAT 는 quatInv(q_SAT2ECI)
            om_des_sat = quatvrot(quatInv(q_SAT2ECI), om_LVLH_eci);
            
            % Rate error in SAT frame
            om_err_sat = om_sat - om_des_sat;
            
            % Use omega error (instead of om_sat) in the PD controller
            t_ctrl = ctrlRwQuat(I_b, qErr, om_err_sat);

        case 4  % Interactive
            disp(['time: ',num2str(t),' sec'])
            t_ctrl = ctrlRwOm(I_b, omTrgt_sat, om_sat);
            pause(0.1); drawnow;
            
        case 5
            om_sat_prev = xs(1:3, n);
            
            t_ctrl  = ctrlRateDamping('x', I_b, om_sat, om_sat_prev);
            t_speed = -ctrlWheelspeed('z', om_rw, [0;0;20]);
            
            t_ctrl(3) = t_speed(3);

        case 6  % Headless Mode (ECI frame rate control)
            disp(['[Headless] time: ',num2str(t),' sec'])
            % ECI 기준 목표 각속도를 body frame으로 변환 후 PD 제어
            t_ctrl = ctrlRwOmHeadless(I_b, omTrgt_eci, om_sat, q_SAT2ECI);
            pause(0.1); drawnow;

        case 7  % Ground Target Pointing (Jeju-do)
            [t_ctrl, qErr_tgt, tgt_info] = ctrlTargetPointing( ...
                I_b, q_SAT2ECI, om_sat, r_sat, v_sat, simTime, omegaEarth);
            
            qE(:,k) = qErr_tgt;
            
            % pointing_error_deg 계산
            pointing_error_deg = 2 * acosd(min(1, abs(qErr_tgt(1))));
            
            if mod(n, 5) == 0
                fprintf('[Target] Off-nadir: %.1f° | LOS dist: %.0f km | Pointing err: %.3f°\n', ...
                    tgt_info.off_nadir_deg, tgt_info.los_distance_km, pointing_error_deg);
            end
            
        otherwise
            warning('mode: wrong ctrl type')
            break
    end

    T_rw = actRW(t_ctrl); % RW as actuator (actuator 출력)
    
    %% =========================================================================
    %% === cmd/actual 각속도 & 자세 기록 ===
    om_act_hist(:,n+1) = xs(1:3,n+1);
    
    if ctrl_mode == 6
        % Headless: ECI 목표를 body로 변환하여 기록
        om_cmd_hist(:,n+1) = quatvrot(quatInv(q_SAT2ECI), omTrgt_eci);
    else
        om_cmd_hist(:,n+1) = omTrgt_sat;
    end
    
    q_act = xs(4:7,n+1);
    
    q_cmd = propagateQuat(q_cmd, omTrgt_sat, tstep);
    
    e_act = quat2euler321(q_act);
    e_cmd = quat2euler321(q_cmd);
    euler_act_deg(:,n+1) = rad2deg(e_act);
    euler_cmd_deg(:,n+1) = rad2deg(e_cmd);

    %% === 실시간 그래프 업데이트 ===
    if enableMatlabPlots && mod(n, plotUpdateInterval) == 0
        try
        % 각속도 그래프 업데이트
        addpoints(h_roll_cmd, t, rad2deg(omTrgt_sat(1)));
        addpoints(h_roll_act, t, rad2deg(xs(1,n+1)));
        
        addpoints(h_pitch_cmd, t, rad2deg(omTrgt_sat(2)));
        addpoints(h_pitch_act, t, rad2deg(xs(2,n+1)));
        
        addpoints(h_yaw_cmd, t, rad2deg(omTrgt_sat(3)));
        addpoints(h_yaw_act, t, rad2deg(xs(3,n+1)));
        
        % 자세 그래프 업데이트
        addpoints(h_phi_cmd, t, euler_cmd_deg(1,n+1));
        addpoints(h_phi_act, t, euler_act_deg(1,n+1));
        
        addpoints(h_theta_cmd, t, euler_cmd_deg(2,n+1));
        addpoints(h_theta_act, t, euler_act_deg(2,n+1));
        
        addpoints(h_psi_cmd, t, euler_cmd_deg(3,n+1));
        addpoints(h_psi_act, t, euler_act_deg(3,n+1));
        
        % 그래프 화면 갱신
        drawnow limitrate;
        catch plotErr
            if ~plotWarningShown
                warning('[plot] MATLAB plot update disabled: %s', plotErr.message);
                plotWarningShown = true;
            end
            enableMatlabPlots = false;
        end
    end
    
    % Extract the latest state for Cesium
    omega_body = xs(1:3, n+1);
    quat_cesium = [xs(5:7, n+1); xs(4, n+1)];  % (x,y,z,w) for Cesium
    pos_eci = xs(11:13, n+1);
    vel_eci = xs(14:16, n+1);
    
    % Convert ECI to ECEF
    [pos_ecef, vel_ecef] = eci2ecef(pos_eci, vel_eci, simTime, omegaEarth);
     
    pos_ecef_m = pos_ecef * 1e3;
    vel_ecef_m = vel_ecef * 1e3;
    pos_eci_m = pos_eci * 1e3;
    vel_eci_m = vel_eci * 1e3;

    %% =========================================================================
    om_rw = xs(8:10, n+1);
    wheel_speeds_rpm = om_rw * 30 / pi;  % rad/s -> rpm
    
    %% =========================================================================
    if ctrl_mode == 2 || ctrl_mode == 3
        pointing_error_deg = 2 * acosd(min(1, abs(qE(1,n+1))));
    elseif ctrl_mode == 7
        % pointing_error_deg already computed in case 7 above
    else
        pointing_error_deg = 0;
    end

    %% =========================================================================
    try
        % Create telemetry structure
        telemetry = struct();
        telemetry.type = 'telemetry';
        telemetry.time = t;
        telemetry.sim_elapsed = simTime;
        telemetry.simDate = datestr(currentSimTime, 'yyyy-mm-dd HH:MM:SS.FFF');
        
        % Include both ECI and ECEF coordinates
        telemetry.position_eci = pos_eci_m;
        telemetry.velocity_eci = vel_eci_m;
        telemetry.position_ecef = pos_ecef_m;
        telemetry.velocity_ecef = vel_ecef_m;
        
        telemetry.quaternion      = quat_cesium;
        telemetry.angularVelocity = omega_body;
        telemetry.targetRates     = rad2deg(omTrgt_sat);
        
        % Headless 모드일 때 ECI 기준 목표 각속도도 포함
        if ctrl_mode == 6
            telemetry.targetRates_eci = rad2deg(omTrgt_eci);
            telemetry.targetRates     = rad2deg(quatvrot(quatInv(q_SAT2ECI), omTrgt_eci));
        end
        
        telemetry.euler321_actual_deg = euler_act_deg(:,n+1);
        telemetry.euler321_cmd_deg    = euler_cmd_deg(:,n+1);
        
        telemetry.ctrl_mode = ctrl_mode;
        telemetry.ctrl_mode_name = ctrl_mode_names{ctrl_mode+1};
        
        telemetry.wheel_speeds_rpm = wheel_speeds_rpm;
        
        if ctrl_mode == 2 || ctrl_mode == 3
            telemetry.pointing_error_deg = pointing_error_deg;
        end
        
        % Mode 7 pointing diagnostics stay satellite/control-only in telemetry.
        if ctrl_mode == 7
            telemetry.pointing_error_deg = pointing_error_deg;
        end

        % Write satellite telemetry to JSON file
        fid = fopen(telemetryFile, 'w');
        fprintf(fid, '%s', jsonencode(telemetry));
        fclose(fid);

        % Write target-only data to a separate JSON file
        fid = fopen(targetFile, 'w');
        fprintf(fid, '%s', jsonencode(targetPacket));
        fclose(fid);
        
    catch e
        disp(['Error writing output JSON file: ', e.message]);
    end

    if mod(n, 5) == 0
        if ctrl_mode == 2 || ctrl_mode == 3 || ctrl_mode == 7
            fprintf('[t=%6.0fs] Mode %d: %s | Pointing Error: %.3f deg | RW: [%.1f, %.1f, %.1f] rpm\n', ...
                    t, ctrl_mode, ctrl_mode_names{ctrl_mode+1}, pointing_error_deg, ...
                    wheel_speeds_rpm(1), wheel_speeds_rpm(2), wheel_speeds_rpm(3));
        else
            fprintf('[t=%6.0fs] Mode %d: %s | omega: [%.3f, %.3f, %.3f] deg/s\n', ...
                    t, ctrl_mode, ctrl_mode_names{ctrl_mode+1}, ...
                    rad2deg(omega_body(1)), rad2deg(omega_body(2)), rad2deg(omega_body(3)));
        end
    end

    % Prevent MATLAB from becoming unresponsive
    pause(1);
end

disp('Simulation complete!');
disp('실시간 그래프가 fig_rate, fig_att 창에 표시되어 있습니다.');

%% ---------- Local functions ----------
function q_next = propagateQuat(q, om, dt)
% q: [4x1] (q0,q1,q2,q3), om: [3x1] rad/s, dt: [s]
wx = om(1); wy = om(2); wz = om(3);
OM = [  0   -wx   -wy   -wz;
       wx     0    wz   -wy;
       wy   -wz     0    wx;
       wz    wy   -wx     0 ];
q_next = q + 0.5 * OM * q * dt;
q_next = q_next / norm(q_next);
end

function e = quat2euler321(q)
% q: [q0;q1;q2;q3] (scalar-first)
q0 = q(1); q1 = q(2); q2 = q(3); q3 = q(4);
phi = atan2( 2*(q0*q1 + q2*q3), 1 - 2*(q1^2 + q2^2) );
theta = asin( max(-1, min(1, 2*(q0*q2 - q3*q1))) );
psi = atan2( 2*(q0*q3 + q1*q2), 1 - 2*(q2^2 + q3^2) );
e = [phi; theta; psi];
end

%% =========================================================================
function T = ctrlRateDamping(axis, I_b, om_current, om_prev)
% Rate damping for specific axis (from quatDynClosedLoop.m case 5)
% axis: 'x', 'y', or 'z'
% I_b: Inertia tensor
% om_current, om_prev: current and previous angular rates
Kd = 0.1;
T = zeros(3,1);
switch axis
    case 'x'
        T(1) = -Kd * om_current(1);
    case 'y'
        T(2) = -Kd * om_current(2);
    case 'z'
        T(3) = -Kd * om_current(3);
end
end

function T = ctrlWheelspeed(axis, om_rw, target_speed)
% Wheel speed controller for momentum bias (from quatDynClosedLoop.m case 5)
% axis: 'x', 'y', or 'z'
% om_rw: current wheel angular velocity [rad/s]
% target_speed: target wheel speed vector [rad/s]
Kp = 0.01;
T = zeros(3,1);
switch axis
    case 'x'
        T(1) = Kp * (om_rw(1) - target_speed(1));
    case 'y'
        T(2) = Kp * (om_rw(2) - target_speed(2));
    case 'z'
        T(3) = Kp * (om_rw(3) - target_speed(3));
end
end
%% =========================================================================
