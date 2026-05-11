function setup_path()
%SETUP_PATH  이 레포지토리를 실행하기 위한 MATLAB 경로(path) 설정 함수
% - 이 파일(setup_path.m)은 반드시 "레포 루트(최상위)"에 두세요.
% - 목적:
%   1) src/ 아래에 있는 함수들이 어디서든 호출되도록 path에 추가
%   2) (선택) main/ 아래 스크립트도 편하게 실행 가능하도록 path에 추가
%   3) (선택) 기존 코드가 상대경로를 많이 쓴다면 레포 루트로 cd 해서 호환 유지

    % 1) 레포 루트 경로 찾기
    % setup_path.m 파일이 있는 위치가 곧 레포 루트이므로 그 경로를 가져옵니다.
    repoRoot = fileparts(mfilename('fullpath'));            % mfilename : "현재 실행 중인 m파일의 이름/경로"를 알려주는 MATLAB 내장 함수, 'fullpath' 옵션을 주면 **이 파일의 전체 경로(절대경로)**를 문자열로 반환
    % fileparts : 경로에서 폴더/파일이름/확장자를 분리해주는 함수, ex)C:\Users\...\VLEO-Simulator

    % 2) (선택) 현재 작업 폴더를 레포 루트로 이동
    % 예전에 한 폴더에 모든 파일이 있었을 때처럼,
    % 상대경로로 파일을 여는 코드(fopen('data/..') 같은)가 많으면 도움이 됩니다.
    % 단, 장기적으로는 fullfile(repoRoot, ...) 형태로 바꾸는 것이 더 안전합니다.
    %cd(repoRoot);

    % 3) src 폴더(및 하위 폴더 전체)를 MATLAB path에 추가
    % 이렇게 하면 src/ 아래로 옮긴 함수들을 기존 호출 방식 그대로(함수이름만) 쓸 수 있습니다.
    addpath(genpath(fullfile(repoRoot, 'src')));    %fullfile : 운영체제에 맞는 구분자로 경로를 이어줌, genpath : 그 폴더 아래 모든 하위폴더까지 포함한 path 문자열을 만들어줌

    % 4) (선택) main 폴더를 MATLAB path에 추가
    % main 폴더에 실행 스크립트가 있을 때, run(...) 없이 스크립트 이름만으로 실행하고 싶다면 켜두세요.
    % 예: main_InteractiveSatControlv7
    % 만약 항상 run(fullfile('main','...'))로 실행할 거면 아래 줄을 주석 처리해도 됩니다.
    addpath(fullfile(repoRoot, 'main'));      

    % 5) 참고: data/docs는 보통 path에 올리지 않습니다.
    % - data는 파일 경로로 접근(fullfile(repoRoot,'data',...))
    % - docs는 문서 폴더라서 path에 올릴 필요가 없습니다.

    % 6) 확인용 출력(원하면 삭제 가능)
    fprintf('[setup_path] 레포 루트: %s\n', repoRoot);
    fprintf('[setup_path] src 경로 추가 완료\n');

end
