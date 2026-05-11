% MATLAB startup wrapper for run_refactored.bat.
% The batch file starts MATLAB from the repository root, so this script can
% use pwd instead of passing Korean or spaced paths through MATLAB's -r option.
setup_path();
run(fullfile(pwd, 'main', 'main_InteractiveSatControlvJeju.m'));
