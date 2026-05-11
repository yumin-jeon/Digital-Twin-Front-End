function targets = loadTargetTrajectories(unifiedDir)
%LOADTARGETTRAJECTORIES Load target trajectories with a common runtime schema.
%
% Output target fields:
%   id, source, category, type
%   scenario_elapsed [Nx1 seconds]
%   position_ecef    [Nx3 meters]
%   velocity_ecef    [Nx3 meters/second]

targets = struct('id', {}, 'source', {}, 'category', {}, 'type', {}, ...
                 'scenario_elapsed', {}, 'position_ecef', {}, 'velocity_ecef', {});

if ~exist(unifiedDir, 'dir')
    warning('[loadTargetTrajectories] unified directory not found: %s', unifiedDir);
    return;
end

sources = {'adsb', 'ais', 'projectile'};

for si = 1:numel(sources)
    sourceName = sources{si};
    sourceDir = fullfile(unifiedDir, sourceName);
    if ~exist(sourceDir, 'dir')
        continue;
    end

    files = dir(fullfile(sourceDir, '*.json'));
    for fi = 1:numel(files)
        filePath = fullfile(files(fi).folder, files(fi).name);
        try
            raw = jsondecode(fileread(filePath));
        catch err
            warning('[loadTargetTrajectories] JSON parse failed (%s): %s', files(fi).name, err.message);
            continue;
        end

        if ~isfield(raw, 'trace') || isempty(raw.trace)
            continue;
        end

        trace = traceToMatrix(raw.trace);
        if isempty(trace) || size(trace, 2) < 4
            continue;
        end

        if strcmp(sourceName, 'adsb') && size(trace, 2) >= 7
            missingAlt = ~isfinite(trace(:, 4)) & isfinite(trace(:, 7));
            trace(missingAlt, 4) = trace(missingAlt, 7);
        end

        validRows = all(isfinite(trace(:, 1:4)), 2);
        trace = trace(validRows, :);
        if isempty(trace)
            continue;
        end

        timeReference = getCharField(raw, 'time_reference', 'sim_elapsed');
        rawTime = normalizeTime(raw, trace(:, 1), timeReference);
        if isempty(rawTime)
            continue;
        end

        lla = trace(:, 2:4);
        scenarioElapsed = rawTime(:) - min(rawTime(:));

        [scenarioElapsed, sortIdx] = sort(scenarioElapsed);
        lla = lla(sortIdx, :);
        [scenarioElapsed, uniqueIdx] = unique(scenarioElapsed, 'stable');
        lla = lla(uniqueIdx, :);

        if isempty(scenarioElapsed)
            continue;
        end

        positionEcef = llaToEcefMeters(lla);
        velocityEcef = computeVelocity(positionEcef, scenarioElapsed);

        idx = numel(targets) + 1;
        targets(idx).id = getCharField(raw, 'id', erase(files(fi).name, '.json'));
        targets(idx).source = getCharField(raw, 'source', sourceName);
        targets(idx).category = sourceToCategory(targets(idx).source);
        targets(idx).type = getCharField(raw, 'type', targets(idx).category);
        targets(idx).scenario_elapsed = scenarioElapsed(:);
        targets(idx).position_ecef = positionEcef;
        targets(idx).velocity_ecef = velocityEcef;
    end
end

fprintf('[loadTargetTrajectories] %d targets loaded from %s\n', numel(targets), unifiedDir);
end

function value = getCharField(raw, fieldName, defaultValue)
if isfield(raw, fieldName) && ~isempty(raw.(fieldName))
    rawValue = raw.(fieldName);
    if ischar(rawValue)
        value = rawValue;
    elseif isstring(rawValue)
        value = char(rawValue);
    elseif isnumeric(rawValue)
        value = num2str(rawValue);
    else
        value = char(string(rawValue));
    end
else
    value = defaultValue;
end
end

function rawTime = normalizeTime(raw, traceTime, timeReference)
switch timeReference
    case 'unix_offset'
        if ~isfield(raw, 'timestamp') || isempty(raw.timestamp)
            rawTime = [];
        else
            rawTime = double(raw.timestamp) + double(traceTime);
        end
    case 'unix_absolute'
        rawTime = double(traceTime);
    otherwise
        rawTime = double(traceTime);
end
end

function category = sourceToCategory(sourceName)
switch lower(sourceName)
    case 'adsb'
        category = 'aircraft';
    case 'ais'
        category = 'ship';
    case 'projectile'
        category = 'projectile';
    otherwise
        category = 'target';
end
end

function trace = traceToMatrix(rawTrace)
if isnumeric(rawTrace)
    trace = double(rawTrace);
    return;
end

if ~iscell(rawTrace)
    trace = [];
    return;
end

nRows = numel(rawTrace);
nCols = 0;
for i = 1:nRows
    row = rawTrace{i};
    if iscell(row)
        nCols = max(nCols, numel(row));
    elseif isnumeric(row)
        nCols = max(nCols, numel(row));
    end
end

trace = nan(nRows, nCols);
for i = 1:nRows
    row = rawTrace{i};
    if isnumeric(row)
        rowValues = row;
    elseif iscell(row)
        rowValues = nan(1, numel(row));
        for j = 1:numel(row)
            if isnumeric(row{j}) && ~isempty(row{j})
                rowValues(j) = double(row{j});
            end
        end
    else
        continue;
    end
    trace(i, 1:numel(rowValues)) = double(rowValues(:))';
end
end

function ecef = llaToEcefMeters(lla)
a = 6378137.0;
f = 1 / 298.257223563;
e2 = f * (2 - f);

lat = deg2rad(lla(:, 1));
lon = deg2rad(lla(:, 2));
alt = lla(:, 3);

sinLat = sin(lat);
cosLat = cos(lat);
N = a ./ sqrt(1 - e2 .* sinLat.^2);

x = (N + alt) .* cosLat .* cos(lon);
y = (N + alt) .* cosLat .* sin(lon);
z = (N .* (1 - e2) + alt) .* sinLat;
ecef = [x, y, z];
end

function velocity = computeVelocity(position, time)
n = numel(time);
velocity = zeros(n, 3);

if n < 2
    return;
end

for i = 1:n
    if i == 1
        i0 = 1;
        i1 = 2;
    elseif i == n
        i0 = n - 1;
        i1 = n;
    else
        i0 = i - 1;
        i1 = i + 1;
    end

    dt = time(i1) - time(i0);
    if dt > 0
        velocity(i, :) = (position(i1, :) - position(i0, :)) ./ dt;
    end
end
end
