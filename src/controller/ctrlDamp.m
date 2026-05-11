function T = ctrlDamp(om)
%% Rate daming

% om: angular rate [3x1]
% T: output torque [Nms]

Kd = 0.02; % D factor
T = -Kd * om;
