function [r_ecef, v_ecef] = eci2ecef(r_eci, v_eci, simTime, omegaEarth)
% ECI2ECEF - Convert from Earth-Centered Inertial (ECI) to Earth-Centered Earth-Fixed (ECEF)
%
% Inputs:
%   r_eci      - Position vector in ECI frame [km] (3x1)
%   v_eci      - Velocity vector in ECI frame [km/s] (3x1)
%   simTime    - Simulation time in seconds from start
%   omegaEarth - Earth's rotation rate [rad/s]
%
% Outputs:
%   r_ecef     - Position vector in ECEF frame [km] (3x1)
%   v_ecef     - Velocity vector in ECEF frame [km/s] (3x1)
%
% This function performs a simplified conversion from ECI to ECEF coordinates
% based on Earth's rotation around the z-axis. For high-precision applications,
% a more complex model including precession, nutation, and polar motion would
% be needed.

    % Calculate the rotation angle based on simulation time
    theta = mod(omegaEarth * simTime, 2*pi);
    
    % Create the rotation matrix from ECI to ECEF (around z-axis)
    R_eci2ecef = [cos(theta), sin(theta), 0;
                 -sin(theta), cos(theta), 0;
                        0,         0,     1];
    
    % Convert position vector from ECI to ECEF
    r_ecef = R_eci2ecef * r_eci;
    
    % For velocity, we need to account for the rotation of the reference frame
    omega_earth_vec = [0; 0; omegaEarth];
    v_ecef = R_eci2ecef * v_eci - cross(omega_earth_vec, r_ecef);
end