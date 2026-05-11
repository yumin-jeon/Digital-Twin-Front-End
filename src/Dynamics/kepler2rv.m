function [r_eci, v_eci] = kepler2rv(a, e, i, RAAN, omega, theta, mu)

% Converts Keplerian elements to ECI state vector (position and velocity)
%
% Inputs:
%   a      - semi-major axis (km)
%   e      - eccentricity
%   i      - inclination (rad)
%   RAAN   - right ascension of ascending node (rad)
%   omega  - argument of periapsis (rad)
%   theta  - true anomaly (rad)
%   mu     - gravitational parameter (km^3/s^2)
%
% Outputs:
%   r_eci  - position vector in ECI frame (3x1) [km]
%   v_eci  - velocity vector in ECI frame (3x1) [km/s]

    % 1. Compute distance (radius)
    r = a * (1 - e^2) / (1 + e * cos(theta));

    % 2. Position in perifocal (PQW) frame
    r_pqw = [r * cos(theta);
             r * sin(theta);
             0];

    % 3. Velocity in perifocal frame
    h = sqrt(mu * a * (1 - e^2));
    v_pqw = [-mu / h * sin(theta);
              mu / h * (e + cos(theta));
              0];

    % 4. Rotation matrix from PQW to ECI
    R = rotationMatrix(RAAN, i, omega);

    % 5. Rotate to ECI
    r_eci = R * r_pqw;
    v_eci = R * v_pqw;
end

function R = rotationMatrix(RAAN, i, omega)
% Builds rotation matrix from perifocal to ECI
    Rz_RAAN = [cos(RAAN), -sin(RAAN), 0;
               sin(RAAN),  cos(RAAN), 0;
               0,              0,     1];
    Rx_i = [1,     0,           0;
            0, cos(i), -sin(i);
            0, sin(i),  cos(i)];
    Rz_omega = [cos(omega), -sin(omega), 0;
                sin(omega),  cos(omega), 0;
                0,               0,      1];
    % Overall rotation: R = Rz(RAAN) * Rx(i) * Rz(omega)
    R = Rz_RAAN * Rx_i * Rz_omega;
end
