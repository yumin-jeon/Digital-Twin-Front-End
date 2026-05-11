function Tout = actRW(Tin)
% function to model reaction wheel behaviour
% Tin: input torque [Nms]
% Tout: output torque [Nms]

Tlim = 0.05; % RW torque limit [Nms]

if norm(Tin) > Tlim
    Tout = Tin *Tlim /norm(Tin);
else
    Tout = Tin;
end
