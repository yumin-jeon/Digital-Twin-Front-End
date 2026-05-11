function a_j2 = j2_perturbation(r, mu, J2, R)
    x = r(1); y = r(2); z = r(3);
    r_norm = norm(r);
    zx2 = 5 * z^2 / r_norm^2;
    factor = (3/2) * J2 * mu * R^2 / r_norm^5;

    ax = factor * x * (1 - zx2);
    ay = factor * y * (1 - zx2);
    az = factor * z * (3 - zx2 * 5);

    a_j2 = [ax; ay; az];
end