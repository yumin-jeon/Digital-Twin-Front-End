function q = dcm2quat( DCM )
  q = sqrt( abs( [
    1 + DCM(1, 1) + DCM(2, 2) + DCM(3, 3)
    1 + DCM(1, 1) - DCM(2, 2) - DCM(3, 3)
    1 - DCM(1, 1) + DCM(2, 2) - DCM(3, 3)
    1 - DCM(1, 1) - DCM(2, 2) + DCM(3, 3)
  ] ) )/2;
  
  [~, idx] = max( abs( q ) );
  
  switch( idx )
    case 1
      q = [
	q(1)
	(DCM(3, 2) - DCM(2, 3))/(4*q(1))
	(DCM(1, 3) - DCM(3, 1))/(4*q(1))
	(DCM(2, 1) - DCM(1, 2))/(4*q(1))
      ];
      
    case 2
      q = [
	(DCM(3, 2) - DCM(2, 3))/(4*q(2))
	q(2)
	(DCM(2, 1) + DCM(1, 2))/(4*q(2))
	(DCM(1, 3) + DCM(3, 1))/(4*q(2))
      ];
      
    case 3
      q = [
	(DCM(1, 3) - DCM(3, 1))/(4*q(3))
	(DCM(2, 1) + DCM(1, 2))/(4*q(3))
	q(3)
	(DCM(3, 2) + DCM(2, 3))/(4*q(3))
      ];
      
    case 4
      q = [
	(DCM(2, 1) - DCM(1, 2))/(4*q(4))
	(DCM(1, 3) + DCM(3, 1))/(4*q(4))
	(DCM(3, 2) + DCM(2, 3))/(4*q(4))
	q(4)
      ];
  end
end