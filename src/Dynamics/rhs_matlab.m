function dx = rhs_matlab( t, X, I_b, I_rw, T_ex, T_rw, mu, J2, R)
% right hand side of ODE to solve dynamics with reaction wheel
% dx: derivative of state vector [10 x 1] 
% X state vector [10 x 1] 
% X(1:3): angular rate spacecraft [rad/s]
% X(4:7): quaternion spacecraft
% X(8:10): angular rate wheel [rad/s]
% X(11:13): satellite orbital position [km]
% X(14:16): satellite orbital velocity [km/s]

% I_b: inertia tensor of satellite incl. wheel [kgm^2]
% I_rw: inertia tensor of wheel [kgm^2]
% external torque [Nms]
% torque from reaction wheel [Nms]

  dx = zeros( size( X ) );
  om_cross = [0 -X(3) X(2); X(3) 0 -X(1); -X(2) X(1) 0];
  OM = [   0  -X(1)   -X(2)   -X(3);
        X(1)      0    X(3)   -X(2);
        X(2)  -X(3)       0    X(1);
        X(3)   X(2)   -X(1)      0];

  dx(1:3)= inv(I_b+I_rw) * (T_ex - T_rw - om_cross * ((I_b+I_rw) * X(1:3)+I_rw*X(8:10))); %dynamics (omega_sat dot)
  % dx(1:3)= I_b\  (T_ex - cross(X(1:3), I_b * X(1:3) + I_rw * (X(8:10) +
  % X(1:3))) -T_rw);%dynamics (omega_sat dot)  Paluszek ADCS 6-24
  dx(4:7) =  0.5 * OM * X(4:7); % kinematics (q dot)
  dx(8:10) = inv(I_rw) * (T_rw); %(omega_rw dot)
   % dx(8:10) = (I_rw\ T_rw) - dx(1:3); %(omega_rw dot), Paluszek ADCS 6-25
  
%% orbit propagation
    r = X(11:13);
    v = X(14:16);

    r_norm = norm(r);

    % Two-body gravitational acceleration
    a_grav = -mu * r / r_norm^3;

    % J2 perturbation acceleration
    a_j2 = j2_perturbation(r, mu, J2, R);

    % Total acceleration
    a_total = a_grav + a_j2;

    dx(11:13) = v;
    dx(14:16) = a_total;
    %dydt = [v; a_total];
end