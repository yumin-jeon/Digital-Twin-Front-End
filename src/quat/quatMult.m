function q = quatMult( q1, q2 )
  q = [
    q1(1,:) .* q2(1,:) - dot( q1(2:4,:), q2(2:4,:) ),
    q1(1,:).*q2(2:4,:) + q2(1,:).*q1(2:4,:) + cross( q1(2:4,:), q2(2:4,:) )
  ];
%q = q ./ vecnorm(q);

end