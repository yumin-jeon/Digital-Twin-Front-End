function T = ctrlRwOm(I_b, om_trgt, om_actual)
% PD angular rate controller
% I_b: Inertia tensor of spacecraft [kgm^2]
% om_trgt: angular rate target [3x1]
% om_actual: angular rate actual [3x1]
% T: output torque [Nms]

Kp = diag([.4, .4, .4]);  % proportional gain
Kd = diag([.2, .2, .2]);  % derivative gain
T =  -Kp  * (om_trgt-om_actual) - Kd * (I_b \ (cross(om_actual, I_b*om_actual)) ); % PD controller
end