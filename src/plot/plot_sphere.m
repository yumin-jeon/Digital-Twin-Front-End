function plot_sphere(rd, alpha)
% Creating axis and sphere for plot
% rd: radius of sphere
% alpha(0.3) % set transparency (0:transparent 1:opaque)  



%-- plot sphere
[a,b,c]=sphere(24);                         % coordinates for sphere
mesh(rd*a,rd*b,rd*c,'FaceColor','white','EdgeColor',[.3 .3 .3],'EdgeAlpha',0.8, 'FaceAlpha',alpha,...
    'LineWidth',1); % plotting sphere with mesh
hold on;
%alpha(0.3) % set transparency (0:transparent 1:opaque)  

%-- plot axis
axis_len = rd * 1.3;
quiver3(0, 0, 0, axis_len, 0, 0, 'r', 'LineWidth', 1.5, 'MaxHeadSize', 0.3);
quiver3(0, 0, 0, 0, axis_len, 0, 'g', 'LineWidth', 1.5, 'MaxHeadSize', 0.3);
quiver3(0, 0, 0, 0, 0, axis_len, 'b', 'LineWidth', 1.5, 'MaxHeadSize', 0.3);
text(axis_len*1.05, 0, 0, 'X', 'Color', 'r', 'FontSize', 12);
text(0, axis_len*1.05, 0, 'Y', 'Color', 'g', 'FontSize', 12);
text(0, 0, axis_len*1.05, 'Z', 'Color', 'b', 'FontSize', 12);

hidden off; axis off equal vis3d;
%-- set camera angle
view(120,30);
%set(gca,'xdir','reverse','zdir','reverse')