%% quatDynClosedLoop.m
%% script for solving rigid body dynamics and kinematics with closed loop control
%% Author: Zizung Yoon
%% (Edited) Body-frame axes (bX,bY,bZ) visualization added in Attitude Animation
%% (Edited) quat2dcm input shape fixed (1x4 row)

close all
clear all
display('Run simulation');

%% Constants
mu_earth = 398600.4418;       % [km^3/s^2]
R_earth  = 6378.137;          % [km] Earth equatorial radius
J2       = 1.08262668e-3;     % [-] Earth's J2 coefficient

%% Define orbital elements
a     = 7000;              % SMA [km]
e     = 0.01;              % eccentricity
i     = deg2rad(98);       % inclination [rad]
RAAN  = deg2rad(90);       % RAAn  [rad]
omega = deg2rad(20);       % Arg. of Perigee  [rad]
theta = deg2rad(0);        % true anomaly [rad]

% Get state vector
[rsat_eci0, vsat_eci0] = kepler2rv(a, e, i, RAAN, omega, theta, mu_earth);

%% satellite property
I_b  = [5 0 0; 0 6 0; 0 0 7];      % moi satellite [kgm^2]
I_rw = [.01 0 0; 0 .01 0; 0 0 .01];% moi wheel [kgm^2]

%% initial condition
q0 = [0.7071; 0.7071; 0; 0];       % sat attitude w.r.t inertial frame, (SAT->ECI 라고 가정해서 쓰는 변수명 q_SAT2ECI로 사용)
om_sat0 = deg2rad([0; 0; 0]);      % sat angular rate [rad/s]
om_rw0  = convangvel([0;0;0],'rpm','rad/s'); % wheel rate [rad/s]

x0 = [om_sat0; q0; om_rw0; rsat_eci0; vsat_eci0]; % initial state vector

T_ext = [-0; 0; 0]; % external torque [Nms]
T_rw  = [0.00; 0.0; 0.0];% wheel torque in body frame [Nms]

%% simulation setting
tstep = 1;    % step for ode solver [s]
te    = 8000;  % sim end time [s]

qCMD_ECI2SAT  = [1;0;0;0]; % quaternion from ECI to CMD (offset)
qCMD_LVLH2SAT = [1;0;0;0]; % quaternion from LVLH to CMD (offset)

global omTrgt_sat
omTrgt_sat = deg2rad([0; 0; 0]); % target angular rate of sat for rate control

conf.ctrl = 3; % 0: no control 1: constant RW torque 2:IPM 3:NPM 4: interactive 5: momentum bias
conf.T_ext = 2; % 0: off 1: constant 2: damping

switch conf.ctrl
    case 0
        disp('Mode 0: no control torque')
    case 1
        disp('Mode 1: constant RW torque')
    case 2
        disp('Mode 2: Inertial Pointing - quaternion feedback')
    case 3
        disp('Mode 3: Nadir Pointing - quaternion feedback')
    case 4
        disp('Mode 4: Interactive Mode with angular rate control')
        global fig
        fig = figure('Name', 'Press keys here!', ...
                     'KeyPressFcn', @key_callback, ...
                     'NumberTitle', 'off');
        disp('Click the figure window and use arrow keys or PageUp/PageDown');
    case 5
        disp('Mode 5: momentum bias')
    otherwise
        warning('mode: wrong ctrl type')
end

%% pre allocation
tc = zeros(1, te + 1);              % simulation time
xs = zeros(length(x0), te + 1);     % state vector
qE = zeros(4, te+1);                % error quaternion 저장

%% control loop
odeopt = odeset('RelTol',1e-6,'AbsTol',1e-6,'InitialStep',1,'MaxStep',1);

t = 0;
xs(:,1) = x0;
tc(1) = 0;

for n = 1:te
    k_prev = n;
    k = n+1;

    [ts, y] = ode45(@(t,x)rhs_matlab(t,x, I_b, I_rw, T_ext, T_rw, mu_earth, J2, R_earth), ...
                    (t:t+tstep), xs(:, k_prev), odeopt);

    t = ts(end);
    tc(k) = t;
    xs(:,k) = y(end,:).';

    % ===== 현재 스텝 물리량 =====
    om_sat    = xs(1:3,   k);
    q_SAT2ECI = xs(4:7,   k);   % SAT->ECI
    om_rw     = xs(8:10,  k);
    r_sat     = xs(11:13, k);
    v_sat     = xs(14:16, k);

    % External torque option
    switch conf.T_ext
        case 0
            T_ext = [0;0;0];
        case 1
            % (constant) keep T_ext as is
        case 2
            T_ext = ctrlDamp(om_sat); % damp satellite rate
    end

    % Control torque
    switch conf.ctrl
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
            % Use omega error (instead of om_sat) in the PD controller
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
            om_sat_prev = xs(1:3, k_prev);
            om_rw_prev  = xs(8:10, k_prev);

            t_ctrl  = ctrlRateDamping('x', I_b, om_sat, om_sat_prev);
            t_speed = -ctrlWheelspeed('z', om_rw, [0;0;20]);
            t_ctrl(3) = t_speed(3);

        otherwise
            warning('mode: wrong ctrl type')
            break
    end

    T_rw = actRW(t_ctrl); % RW as actuator (actuator 출력)
end

%% post processing
om_sat     = xs(1:3,:);
q_SAT2ECI  = xs(4:7,:);
om_rw      = xs(8:10,:);
r_sat      = xs(11:13,:);
v_sat      = xs(14:16,:);

om_sat_abs = sqrt(sum(om_sat.^2,1));
r_sat_abs  = sqrt(sum(r_sat.^2,1));
v_sat_abs  = sqrt(sum(v_sat.^2,1));

om_sat_inert = quatvrot(q_SAT2ECI, om_sat);
vec_nadir    = quatvrot(quatInv(q_SAT2ECI), -r_sat);
om_sat_inert_abs = sqrt(sum(om_sat_inert.^2,1));

H_sat = I_b  * om_sat;
H_rw  = I_rw * om_rw;
H_sat_abs = sqrt(sum(H_sat.^2,1));
H_rw_abs  = sqrt(sum(H_rw.^2,1));
H_tot_abs = sqrt(sum((H_sat+H_rw).^2,1));

%% plot: rates, wheels, quaternion, momentum
hfw = figure('name','satellite rate');

subplot(2,2,1); hold on; grid on
plot(tc, om_sat(1,:)*180/pi, '-r')
plot(tc, om_sat(2,:)*180/pi, '-g')
plot(tc, om_sat(3,:)*180/pi, '-b')
plot(tc, om_sat_abs*180/pi, 'k')
xlabel('t [s]'); ylabel('\omega [deg/s]'); title('satellite rate')
legend('\omega_x','\omega_y','\omega_z','\omega_{abs}')

subplot(2,2,2); hold on; grid on
plot(tc, om_rw(1,:)*30/pi, 'r')
plot(tc, om_rw(2,:)*30/pi, 'g')
plot(tc, om_rw(3,:)*30/pi, 'b')
xlabel('t [s]'); ylabel('\omega_i [rpm]'); title('wheel rate')
legend('\omega_x','\omega_y','\omega_z')

subplot(2,2,3); hold on; grid on
plot(tc, q_SAT2ECI(1,:), 'k')
plot(tc, q_SAT2ECI(2,:), 'r')
plot(tc, q_SAT2ECI(3,:), 'g')
plot(tc, q_SAT2ECI(4,:), 'b')
xlabel('t [s]'); ylabel('q_i'); title('Attitude Quaternion')
legend('q_s','q_x','q_y','q_z')

subplot(2,2,4); hold on; grid on
plot(tc, H_sat_abs, 'r')
plot(tc, H_rw_abs, 'g')
plot(tc, H_tot_abs,'k')
xlabel('t [s]'); ylabel('H [Nms]'); title('angular momentum')
legend('|H_{sat}|','|H_{rw}|','|H_{tot}|')

if (conf.ctrl == 2) || (conf.ctrl == 3)
    figure('name','quaternion'); hold on; grid on
    plot(tc, qE(1,:), 'k'); plot(tc, qE(2,:), 'r'); plot(tc, qE(3,:), 'g'); plot(tc, qE(4,:), 'b')
    xlabel('t [s]'); ylabel('q_E'); title('Error Quaternion')
    legend('q_s','q_x','q_y','q_z')
end

%% Raw Body Fixed
figure('name','Raw Body Fixed'); hold on; grid on; axis equal
plot3(om_sat(1,:), om_sat(2,:), om_sat(3,:), 'r')
plot3(om_sat0(1), om_sat0(2), om_sat0(3), 'p', 'MarkerSize',10, 'MarkerFaceColor',[1 .6 .6]);
plot_sphere(norm(om_sat0), 0.6);
xlabel('\omega_x [rad/s]'); ylabel('\omega_y [rad/s]'); zlabel('\omega_z [rad/s]')
title('Satellite Rate, Body Fixed')
legend('\omega_{sat}','\omega_{0}')

%% Unit Sphere Body Fixed Frame
figure('name','Unit Sphere Body Fixed');
plot3(H_sat(1,:)./H_sat_abs, H_sat(2,:)./H_sat_abs, H_sat(3,:)./H_sat_abs,'r.'); hold on;
plot3(om_sat(1,:)./om_sat_abs, om_sat(2,:)./om_sat_abs, om_sat(3,:)./om_sat_abs,'r');
plot3((H_sat(1,:)+H_rw(1,:))./H_tot_abs, (H_sat(2,:)+H_rw(2,:))./H_tot_abs, (H_sat(3,:)+H_rw(3,:))./H_tot_abs,'k.');
plot3(om_sat0(1)/norm(om_sat0), om_sat0(2)/norm(om_sat0), om_sat0(3)/norm(om_sat0), ...
      'p','MarkerSize',10,'MarkerFaceColor',[1 .6 .6]);
plot_sphere(1, 0.6);
grid on; axis equal
title('Unit Sphere, Body Fixed Frame')
legend('H_{Sat}','\omega_{Sat}','H_{total}')

%% Plot Orbit
fig = figure('name','Orbit');
pl1 = plot3(rsat_eci0(1,1), rsat_eci0(2,1), rsat_eci0(3,1), 'Color','b', 'Marker','*', 'DisplayName','start');
hold on
pl2 = plot3(r_sat(1,:), r_sat(2,:), r_sat(3,:), 'Color','b', 'LineStyle','-', 'DisplayName','trajectory');
plot_sphere(R_earth,1.0);
grid on; axis equal
xlabel('x [km]'); ylabel('y [km]'); zlabel('z [km]');
title('Satellite Orbit (Cowell + J2)');
legend([pl1(1), pl2(1)]);

%% Plot Attitude Animation
[element,idx] = satellite3d(0);
scale = 5;
figure('name','Attitude Animation');

% plot initial satellite mesh
for ii = 1:idx
    hp1{ii} = patch('Vertices', element{ii}.XYZ, ...
                    'Faces', element{ii}.faces, ...
                    'FaceColor', element{ii}.facecolor, ...
                    'EdgeColor', element{ii}.edgecolor, ...
                    'LineWidth', element{ii}.LineWidth);
    hold on
end

% initial vectors
hp2 = plot3(scale*[0, om_sat_inert(1,1)./om_sat_abs(1)], ...
            scale*[0, om_sat_inert(2,1)./om_sat_abs(1)], ...
            scale*[0, om_sat_inert(3,1)./om_sat_abs(1)], ...
            '-', 'Color',[0.4940 0.1840 0.5560], 'Marker','.', 'LineWidth',1);

hp4 = plot3(scale*[0,-r_sat(1,1)/r_sat_abs(1)], ...
            scale*[0,-r_sat(2,1)/r_sat_abs(1)], ...
            scale*[0,-r_sat(3,1)/r_sat_abs(1)], ...
            '-m', 'Marker','.', 'LineWidth',1);
hp5 = text(-r_sat(1,1)/r_sat_abs(1)*scale, -r_sat(2,1)/r_sat_abs(1)*scale, -r_sat(3,1)/r_sat_abs(1)*scale, ...
           'Nadir', 'Color','m', 'FontSize',12);

hp6 = plot3(scale*[0, v_sat(1,1)/v_sat_abs(1)], ...
            scale*[0, v_sat(2,1)/v_sat_abs(1)], ...
            scale*[0, v_sat(3,1)/v_sat_abs(1)], ...
            '-c', 'Marker','.', 'LineWidth',1);
hp7 = text(v_sat(1,1)/v_sat_abs(1)*scale, v_sat(2,1)/v_sat_abs(1)*scale, v_sat(3,1)/v_sat_abs(1)*scale, ...
           'Vel', 'Color','c', 'FontSize',12);

hp3 = annotation('textbox', [0.80, 0.9, 0.1, 0.1]);

plot_frame(scale);
hold on;
grid on; xlabel('X'); ylabel('Y'); zlabel('Z');
axis equal
view([-1,1,0.5]);
xlim([-scale*1.5, scale*1.5]); ylim([-scale*1.5, scale*1.5]); zlim([-scale*1.5, scale*1.5]);

%% ===== (ADDED) Body frame axes (bX,bY,bZ) initial draw =====
T_SAT2ECI0 = quat2dcm(q_SAT2ECI(:,1).').';   % SAT -> ECI (columns are body axes in ECI)
bX0 = T_SAT2ECI0(:,1);  bY0 = T_SAT2ECI0(:,2);  bZ0 = T_SAT2ECI0(:,3);

hbX = plot3([0 scale*bX0(1)], [0 scale*bX0(2)], [0 scale*bX0(3)], 'r--', 'LineWidth', 2);
hbY = plot3([0 scale*bY0(1)], [0 scale*bY0(2)], [0 scale*bY0(3)], 'g--', 'LineWidth', 2);
hbZ = plot3([0 scale*bZ0(1)], [0 scale*bZ0(2)], [0 scale*bZ0(3)], 'b--', 'LineWidth', 2);

htbX = text(scale*1.08*bX0(1), scale*1.08*bX0(2), scale*1.08*bX0(3), 'bX', 'Color','r', 'FontWeight','bold');
htbY = text(scale*1.08*bY0(1), scale*1.08*bY0(2), scale*1.08*bY0(3), 'bY', 'Color','g', 'FontWeight','bold');
htbZ = text(scale*1.08*bZ0(1), scale*1.08*bZ0(2), scale*1.08*bZ0(3), 'bZ', 'Color','b', 'FontWeight','bold');

%% ===== (ADDED) LVLH frame axes (lX,lY,lZ) initial draw =====
r0 = r_sat(:,1);  v0 = v_sat(:,1);

lZ0 = -r0 / norm(r0);                 % LVLH z : nadir (toward Earth)
lY0 = -cross(r0, v0);  lY0 = lY0 / norm(lY0);  % LVLH y : -orbit normal (your convention)
lX0 = cross(lY0, lZ0);  lX0 = lX0 / norm(lX0); % LVLH x : completes RH frame

hlX = plot3([0 scale*lX0(1)], [0 scale*lX0(2)], [0 scale*lX0(3)], 'k-.', 'LineWidth', 2);
hlY = plot3([0 scale*lY0(1)], [0 scale*lY0(2)], [0 scale*lY0(3)], 'm-.', 'LineWidth', 2);
hlZ = plot3([0 scale*lZ0(1)], [0 scale*lZ0(2)], [0 scale*lZ0(3)], 'y-.', 'LineWidth', 2);

htlX = text(scale*1.08*lX0(1), scale*1.08*lX0(2), scale*1.08*lX0(3), 'lX', 'Color','k', 'FontWeight','bold');
htlY = text(scale*1.08*lY0(1), scale*1.08*lY0(2), scale*1.08*lY0(3), 'lY', 'Color','m', 'FontWeight','bold');
htlZ = text(scale*1.08*lZ0(1), scale*1.08*lZ0(2), scale*1.08*lZ0(3), 'lZ', 'Color','y', 'FontWeight','bold');


% update satellite
for n = 1:te
    T_SAT2ECI = quat2dcm(q_SAT2ECI(:,n).').';   % SAT -> ECI (FIXED SHAPE)

    % rotate mesh
    for ii = 1:idx
        rotated_vertices = (T_SAT2ECI * element{ii}.XYZ')';
        hp1{ii}.Vertices = rotated_vertices;
    end

    % ===== (ADDED) update BODY axes =====
    bX = T_SAT2ECI(:,1);  bY = T_SAT2ECI(:,2);  bZ = T_SAT2ECI(:,3);
    hbX.XData = [0 scale*bX(1)]; hbX.YData = [0 scale*bX(2)]; hbX.ZData = [0 scale*bX(3)];
    hbY.XData = [0 scale*bY(1)]; hbY.YData = [0 scale*bY(2)]; hbY.ZData = [0 scale*bY(3)];
    hbZ.XData = [0 scale*bZ(1)]; hbZ.YData = [0 scale*bZ(2)]; hbZ.ZData = [0 scale*bZ(3)];

    htbX.Position = scale*1.08*[bX(1) bX(2) bX(3)];
    htbY.Position = scale*1.08*[bY(1) bY(2) bY(3)];
    htbZ.Position = scale*1.08*[bZ(1) bZ(2) bZ(3)];

    % ===== (ADDED) update LVLH axes =====
    r = r_sat(:,n);  v = v_sat(:,n);
    
    lZ = -r / norm(r);
    lY = -cross(r, v);  lY = lY / norm(lY);
    lX = cross(lY, lZ);  lX = lX / norm(lX);
    
    hlX.XData = [0 scale*lX(1)]; hlX.YData = [0 scale*lX(2)]; hlX.ZData = [0 scale*lX(3)];
    hlY.XData = [0 scale*lY(1)]; hlY.YData = [0 scale*lY(2)]; hlY.ZData = [0 scale*lY(3)];
    hlZ.XData = [0 scale*lZ(1)]; hlZ.YData = [0 scale*lZ(2)]; hlZ.ZData = [0 scale*lZ(3)];
    
    htlX.Position = scale*1.08*[lX(1) lX(2) lX(3)];
    htlY.Position = scale*1.08*[lY(1) lY(2) lY(3)];
    htlZ.Position = scale*1.08*[lZ(1) lZ(2) lZ(3)];


    % omega trace + vector
    plot3(scale*om_sat_inert(1,n)./om_sat_abs(n), scale*om_sat_inert(2,n)./om_sat_abs(n), scale*om_sat_inert(3,n)./om_sat_abs(n), ...
          '-.','Color',[0.4940 0.1840 0.5560]);

    hp2.XData = scale*[0, om_sat_inert(1,n)./om_sat_abs(n)];
    hp2.YData = scale*[0, om_sat_inert(2,n)./om_sat_abs(n)];
    hp2.ZData = scale*[0, om_sat_inert(3,n)./om_sat_abs(n)];
    hp2.DisplayName = sprintf('\\omega_{Sat}: [%5.2f %5.2f %5.2f] deg/s', ...
                              om_sat(1,n)*180/pi, om_sat(2,n)*180/pi, om_sat(3,n)*180/pi);

    % nadir vector
    hp4.XData = scale*[0, -r_sat(1,n)/r_sat_abs(n)];
    hp4.YData = scale*[0, -r_sat(2,n)/r_sat_abs(n)];
    hp4.ZData = scale*[0, -r_sat(3,n)/r_sat_abs(n)];
    hp4.DisplayName = sprintf('nadir: [%5.2f %5.2f %5.2f]', ...
                              -r_sat(1,n)/r_sat_abs(n), -r_sat(2,n)/r_sat_abs(n), -r_sat(3,n)/r_sat_abs(n));
    hp5.Position = scale*1.05 * [-r_sat(1,n)/r_sat_abs(n), -r_sat(2,n)/r_sat_abs(n), -r_sat(3,n)/r_sat_abs(n)];

    % velocity vector
    hp6.XData = scale*[0, v_sat(1,n)/v_sat_abs(n)];
    hp6.YData = scale*[0, v_sat(2,n)/v_sat_abs(n)];
    hp6.ZData = scale*[0, v_sat(3,n)/v_sat_abs(n)];
    hp6.DisplayName = sprintf('orb vel: [%5.2f %5.2f %5.2f]', ...
                              v_sat(1,n)/v_sat_abs(n), v_sat(2,n)/v_sat_abs(n), v_sat(3,n)/v_sat_abs(n));
    hp7.Position = scale*1.05 * [v_sat(1,n)/v_sat_abs(n), v_sat(2,n)/v_sat_abs(n), v_sat(3,n)/v_sat_abs(n)];

    legend([hp2(1), hp4(1)], 'Location','northeast');
    hp3.String = sprintf('t   = %5d sec\n', n);

    drawnow;
end
