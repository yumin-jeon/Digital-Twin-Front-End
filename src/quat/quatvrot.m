function v_out = quatvrot( q, v )
%rotates the vector V using the quaternion Q.
% Ensure v is a 3×N matrix
if size(v,1) ~= 3
    error('Input vector v must be 3×N');
end

% Ensure q is a 4×N matrix
if size(q,1) ~= 4
    error('Input quaternion q must be 4×N');
end

vextend = zeros(4, size(v,2)); % Ensure 4xN size
vextend(2:4,:) = v; % make 3xN vector to 4xN
q1=quatMult(q(1:4,:),vextend(1:4,:));
vt=quatMult(q1, quatInv(q));
% Eliminate first element of vt for output
v_out = vt(2:4,:);
end
