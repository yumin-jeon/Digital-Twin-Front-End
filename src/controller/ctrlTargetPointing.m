function [t_ctrl, qErr, target_info] = ctrlTargetPointing( ...
        I_b, q_SAT2ECI, om_sat, r_sat, v_sat, simTime, omegaEarth)
%% ctrlTargetPointing  -  Ground Target Pointing Controller
%  Points satellite body z-axis toward a ground target (Jeju-do).
%
%  Inputs
%    I_b         [3x3]  Spacecraft inertia tensor [kg·m²]
%    q_SAT2ECI   [4x1]  Quaternion SAT->ECI (scalar-first)
%    om_sat      [3x1]  Satellite angular velocity in body frame [rad/s]
%    r_sat       [3x1]  Satellite ECI position [km]
%    v_sat       [3x1]  Satellite ECI velocity [km/s]
%    simTime     [1x1]  Simulation elapsed time [s]
%    omegaEarth  [1x1]  Earth rotation rate [rad/s]
%
%  Outputs
%    t_ctrl      [3x1]  Control torque command [Nm]sea
%    qErr        [4x1]  Error quaternion (scalar-first)
%    target_info struct  Auxiliary data for telemetry

% ===== Target definition (Jeju-do) ======================================
lat_tgt = deg2rad(33.2140);     % geodetic latitude  [rad]
lon_tgt = deg2rad(126.3145);    % geodetic longitude [rad]
alt_tgt = 0;                    % altitude above WGS-84 [km]

% Target position in ECEF using the same WGS-84 model as the Target Layer loader.
r_tgt_ecef = llaToEcefKm(lat_tgt, lon_tgt, alt_tgt);

% ===== ECEF -> ECI (inverse of eci2ecef rotation) =======================
theta_rot  = mod(omegaEarth * simTime, 2*pi);
R_ecef2eci = [ cos(theta_rot), -sin(theta_rot), 0;
               sin(theta_rot),  cos(theta_rot), 0;
               0,                0,              1];
r_tgt_eci = R_ecef2eci * r_tgt_ecef;

% Target velocity in ECI (due to Earth rotation)
omega_e_vec = [0; 0; omegaEarth];
v_tgt_eci   = cross(omega_e_vec, r_tgt_eci);   % [km/s]

% ===== Line-of-sight (LOS) vector: satellite -> target ==================
los_eci      = r_tgt_eci - r_sat;               % [km]
los_dist     = norm(los_eci);                    % slant range [km]
los_eci_unit = los_eci / los_dist;

% ===== Build commanded attitude DCM (ECI -> CMD body) ===================
%  z_body  -> target direction  (camera / payload boresight)
%  y_body  -> perpendicular to orbital plane (orbit-normal reference)
%  x_body  -> completes right-hand frame
z_cmd = los_eci_unit;

% Orbit normal as reference for y-axis
h_vec = cross(r_sat, v_sat);
h_unit = -h_vec / norm(h_vec);

x_cmd = cross(h_unit, z_cmd);
x_norm = norm(x_cmd);
if x_norm < 1e-6
    % Degenerate: LOS ≈ orbit normal  ->  use velocity as fallback
    x_cmd  = cross(v_sat/norm(v_sat), z_cmd);
    x_norm = norm(x_cmd);
end
x_cmd = x_cmd / x_norm;

y_cmd = cross(z_cmd, x_cmd);
y_cmd = y_cmd / norm(y_cmd);

% DCM: ECI -> commanded body frame
R_eci2cmd = [x_cmd'; y_cmd'; z_cmd'];

q_ECI2CMD = dcm2quat(R_eci2cmd);
q_ECI2CMD = q_ECI2CMD(:);
q_ECI2CMD = q_ECI2CMD / norm(q_ECI2CMD);

% ===== Error quaternion ==================================================
qErr = quatMult(q_ECI2CMD, q_SAT2ECI);
qErr = qErr(:);
qErr = qErr / norm(qErr);

% Shortest rotation path
if qErr(1) < 0,  qErr = -qErr;  end

% ===== Feed-forward: LOS angular rate ====================================
%  d(LOS)/dt = (v_tgt - v_sat),  angular rate ≈ LOS × dLOS/dt / |LOS|²
v_rel      = v_tgt_eci - v_sat;                         % [km/s]
om_los_eci = cross(los_eci, v_rel) / (los_dist^2);      % [rad/s]

% Express desired angular rate in body frame
om_des_sat = quatvrot(quatInv(q_SAT2ECI), om_los_eci);  % [rad/s]

% Rate error
om_err = om_sat - om_des_sat;

% ===== PD control (reuses ctrlRwQuat) ====================================
t_ctrl = ctrlRwQuat(I_b, qErr, om_err);

% ===== Target info for telemetry =========================================
target_info.target_ecef    = r_tgt_ecef * 1e3;   % [m]  for Cesium
target_info.target_eci     = r_tgt_eci  * 1e3;   % [m]
target_info.los_distance_km = los_dist;
target_info.target_name    = 'Jeju-do';

% Off-nadir angle
nadir_dir = -r_sat / norm(r_sat);
target_info.off_nadir_deg = acosd( max(-1, min(1, dot(los_eci_unit, nadir_dir))) );

end

function r_ecef = llaToEcefKm(lat, lon, alt)
%LLATOECEFKM Convert geodetic LLA to WGS-84 ECEF coordinates in kilometers.
a = 6378.137;
f = 1 / 298.257223563;
e2 = f * (2 - f);

sinLat = sin(lat);
cosLat = cos(lat);
N = a / sqrt(1 - e2 * sinLat^2);

r_ecef = [ (N + alt) * cosLat * cos(lon);
           (N + alt) * cosLat * sin(lon);
           (N * (1 - e2) + alt) * sinLat ];
end
