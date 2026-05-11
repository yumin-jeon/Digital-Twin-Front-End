function T = ctrlRwQuat(I_b, qE,om_sat)
%% Quaternion feedback control
% I_b: Inertia tensor of spacecraft [kgm^2]
% qE: error quaternion [4x1]
% om: angular rate [3x1]
% T: output torque [Nms]
Kp = 0.13; % P factor
Kd = 0.5; % D factor


T = diag(I_b) .* (Kp  .* qE(2:4) + Kd .* om_sat); 
%T = -diag(I_b) .* (Kp  .* qE(2:4) - Kd .* om);  % 작은 오차에서는 선형화-> 쿼토니언 벡터값이 거의 그냥 각도오차 취급 가능 qv≈uθ/2

% 미분항은 댐퍼 역할
% 같은 토크에 대해 관성이 큰 축은 각가속도 작음, 따라서 축별로 비슷한 응답 주기 위해 관성 크기만큼 스케일링함
