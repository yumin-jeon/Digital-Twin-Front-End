function C = quat2dcm_sf(q)
%QUAT2DCM_SF Convert quaternion to DCM.
% q: 4x1 quaternion, scalar-first [q0;q1;q2;q3]
% C: 3x3 direction cosine matrix.
% Convention: v_body = C * v_eci  (Body <- ECI)

q = q(:);
q = q / norm(q);

q0 = q(1); q1 = q(2); q2 = q(3); q3 = q(4);

C = [ 1-2*(q2^2+q3^2),   2*(q1*q2 + q0*q3),  2*(q1*q3 - q0*q2);
      2*(q1*q2 - q0*q3), 1-2*(q1^2+q3^2),    2*(q2*q3 + q0*q1);
      2*(q1*q3 + q0*q2), 2*(q2*q3 - q0*q1),  1-2*(q1^2+q2^2) ];
end
