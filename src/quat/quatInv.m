function qinv = quatinv(q)
%QUATINV Performs Quaternion inverse for q being a 4xn matrix
%q is of the form: a1 + b1 i + c1 j + d1 k
qinv = [q(1,:); -q(2:4,:)];
end