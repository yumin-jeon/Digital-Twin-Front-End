function [element, idx] = satellite3d(show)
%SATELLITE Summary of this function goes here
%   Detailed explanation goes here

% ========================
% Form
% ========================
Scale = 1;
idx = 0;      % element{} 인덱스 초기화

% ----------------
% axis-x
% ----------------
idx = idx + 1;
element{idx}.Name = 'axis-x';
element{idx}.XYZ = Scale* [ % vertices
    0 0 0;
    +3 0 0];
element{idx}.faces = [1 2];
element{idx}.facecolor = [0.8 0.8 0];
element{idx}.edgecolor =[0.8500 0.3250 0.0980]; %red
element{idx}.LineWidth =2; %
element{idx}.LineWidth =2; %


% ----------------
% axis-y
% ----------------
idx = idx + 1;
element{idx}.Name = 'axis-y';
element{idx}.XYZ = Scale* [ % vertices
    0 0 0;
    0 3 0];
element{idx}.faces = [1 2];
element{idx}.facecolor = [0.8 0.8 0];
element{idx}.edgecolor =[0.4660 0.6740 0.1880]; %green
element{idx}.LineWidth =2; %

% ----------------
% axis-z
% ----------------
idx = idx + 1;
element{idx}.Name = 'axis-z';
element{idx}.XYZ = Scale* [ % vertices
    0 0 0;
    0 0 +3];
element{idx}.faces = [1 2];
element{idx}.facecolor = [0.8 0.8 0];
element{idx}.edgecolor =[0 0.4470 0.7410]; %blue
element{idx}.LineWidth =2; %


% ----------------
% main body
% ----------------
idx = idx + 1;
element{idx}.Name = 'body';
element{idx}.XYZ = Scale* [ % vertices
    +1 -1 -2;
    +1 +1 -2;
    -1 +1 -2;
    -1 -1 -2;
    +1 -1 +2;
    +1 +1 +2;
    -1 +1 +2;
    -1 -1 +2];
element{idx}.faces = [1 2 6 5;2 3 7 6;3 4 8 7;4 1 5 8;1 2 3 4;5 6 7 8];
element{idx}.facecolor = [0.9290 0.6940 0.1250];
element{idx}.edgecolor = [0 0 0];
element{idx}.LineWidth =0.5; %


% ----------------
% solar panel
% ----------------
idx = idx + 1;
element{idx}.Name = 'panel';
element{idx}.XYZ = Scale* [ % vertices
    3 -1.01 -2;
    -3 -1.01 -2;
    -3 -1.01 1.7;
    3 -1.01 1.7];
element{idx}.faces = [1 2 3 4];
element{idx}.facecolor = [0 0 0.8];
element{idx}.edgecolor = [0 0 0];
element{idx}.LineWidth =0.5; %

% ----------------
% Camera Structure
% ----------------
N_for_Cam = 30;
alpha = linspace(0, 2*pi, N_for_Cam);      % 원을 위한 매개변수
cam.D = 1; % camera diameter
cam.pos = [0 0 2.1];
idx = idx + 1;
element{idx}.Name = 'camera';
element{idx}.XYZ = zeros(N_for_Cam,3);     % 행렬 크기 정의
for i = 1:N_for_Cam
    x = cam.pos(1) + 0.5*cam.D*cos(alpha(i));
    y = cam.pos(2)  + 0.5*cam.D*sin(alpha(i));
    z = cam.pos(3) ;
    element{idx}.XYZ(i,:) = [x,y,z];
end
element{idx}.faces = 1:N_for_Cam;
element{idx}.facecolor = [0.3010 0.7450 0.9330];
element{idx}.edgecolor = [0 0 0];
element{idx}.LineWidth =.5; %

%% display
if show ==1
    figure(1);
    hold on;
    for i = 1:idx % Loop through elements
        patch('Vertices', element{i}.XYZ, 'Faces', element{i}.faces, ...
            'FaceColor', element{i}.facecolor, 'EdgeColor', element{i}.edgecolor, 'LineWidth', element{i}.LineWidth);

        % for j = 1:size(element{i}.faces, 1) % Loop through faces
        %     patch('Vertices', element{i}.XYZ, 'Faces', element{i}.faces(j,:), ...
        %         'FaceColor', element{i}.facecolor, 'EdgeColor', element{i}.edgecolor(min(j, end), :));
        % end
        % if strcmp(element{i}.Name,'panel')
        %     set(hp,'FaceColor',[0 0 0.8]);
        %     set(hp,'EdgeColor',[0.7 0.7 0.7]);
        % end
    end

    xlabel('X'); ylabel('Y'); zlabel('Z');
    xlim([-5, 5]); ylim([-5, 5]); zlim([-5, 5]);
    axis equal
    view([-1,1,0.5]);
    grid on;
end


end