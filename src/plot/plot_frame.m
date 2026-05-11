function h = plot_frame(radius)
% Creating axis and sphere for plot
% rd: radius of sphere
% alpha(0.3) % set transparency (0:transparent 1:opaque)  



%-- plot sphere
[a,b,c]=sphere(20);                         % coordinates for sphere
mesh(radius*a,radius*b,radius*c,'FaceColor','none','EdgeColor',[.3 .3 .3],'EdgeAlpha',0.8, 'FaceAlpha',1,...
    'LineWidth',0.1); % plotting sphere with mesh
hold on;

if nargin < 1
        radius = 1; % Default
    end

    theta = linspace(0, 2*pi, 361);
    tick_angles = deg2rad(0:30:330); % 30° interval
    tick_length = 0.05 * radius;

    % === Circle 1: XY plane ===
    x1 = radius * cos(theta);
    y1 = radius * sin(theta);
    z1 = zeros(size(theta));

    % === Circle 2: XZ plane ===
    x2 = radius * cos(theta);
    y2 = zeros(size(theta));
    z2 = radius * sin(theta);

    % === Circle 3: YZ plane ===
    x3 = zeros(size(theta));
    y3 = radius * cos(theta);
    z3 = radius * sin(theta);

    % === Plotting ===
    % figure;
    hold on;
    axis equal;
    grid on;
    view(3);

    plot3(x1, y1, z1, 'r', 'LineWidth', 1);      % XY
    plot3(x2, y2, z2, 'b', 'LineWidth', 1);    % XZ
    % plot3(x3, y3, z3, 'g', 'LineWidth', 1);      % YZ

    % === Ticks for XY plane ===
    % for k = 1:length(tick_angles)
    %     angle = tick_angles(k);
    %     xt = radius * cos(angle);
    %     yt = radius * sin(angle);
    %     dir = [cos(angle); sin(angle)];
    %     xtick = [xt, xt - tick_length * dir(1)];
    %     ytick = [yt, yt - tick_length * dir(2)];
    %     ztick = [0, 0];
    %     plot3(xtick, ytick, ztick, 'k', 'LineWidth', 1);
    % end

    % === Ticks for XZ plane ===
    for k = 1:length(tick_angles)
        angle = tick_angles(k);
        xt = radius * cos(angle);
        zt = radius * sin(angle);
        dir = [cos(angle); sin(angle)];
        xtick = [xt, xt - tick_length * dir(1)];
        ztick = [zt, zt - tick_length * dir(2)];
        ytick = [0, 0];
        plot3(xtick, ytick, ztick, 'k', 'LineWidth', 1);
    end

    % === Ticks for YZ plane ===
    for k = 1:length(tick_angles)
        angle = tick_angles(k);
        yt = radius * cos(angle);
        zt = radius * sin(angle);
        dir = [cos(angle); sin(angle)];
        ytick = [yt, yt - tick_length * dir(1)];
        ztick = [zt, zt - tick_length * dir(2)];
        xtick = [0, 0];
        plot3(xtick, ytick, ztick, 'k', 'LineWidth', 1);
    end

    xlabel('X');
    ylabel('Y');
    % zlabel('Z');
    title(sprintf('3D Circles (radius = %.2f) with 30° Tick Marks', radius));

%-- plot axis
axis_len = radius * 1.0;
quiver3(0, 0, 0, axis_len, 0, 0,1.05, 'r', 'LineWidth', 1, 'MaxHeadSize', 0.1);
quiver3(0, 0, 0, 0, axis_len, 0,1.05, 'g', 'LineWidth', 1, 'MaxHeadSize', 0.1);
quiver3(0, 0, 0, 0, 0, axis_len,1.05, 'b', 'LineWidth', 1, 'MaxHeadSize', 0.1);
text(axis_len*1.1, 0, 0, 'X_{ECI}', 'Color', 'r', 'FontSize', 12);
text(0, axis_len*1.1, 0, 'Y_{ECI}', 'Color', 'g', 'FontSize', 12);
text(0, 0, axis_len*1.1, 'Z_{ECI}', 'Color', 'b', 'FontSize', 12);

hidden off; axis off equal vis3d;
%-- set camera angle
view(120,30);
%set(gca,'xdir','reverse','zdir','reverse')

hold off