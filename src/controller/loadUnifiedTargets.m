function targets = loadUnifiedTargets(unifiedDir)
%LOADUNIFIEDTARGETS Load unified ADS-B/AIS/projectile JSON files for MATLAB.
%
% Output target fields:
%   id, source, type, desc
%   sim_elapsed  [Nx1 seconds]
%   ecef         [Nx3 meters]
%   lla          [Nx3 lat_deg, lon_deg, alt_m]

targets = struct('id', {}, 'source', {}, 'type', {}, 'desc', {}, ...
                 'sim_elapsed', {}, 'ecef', {}, 'lla', {});

if ~exist(unifiedDir, 'dir')
    warning('[loadUnifiedTargets] unified directory not found: %s', unifiedDir);
    return;
end

sources = {'adsb', 'ais', 'projectile'};
rawItems = struct('id', {}, 'source', {}, 'type', {}, 'desc', {}, ...
                  'time_reference', {}, 'raw_time', {}, 'lla', {});
sourceStart = containers.Map('KeyType', 'char', 'ValueType', 'double');

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
            warning('[loadUnifiedTargets] JSON parse failed (%s): %s', files(fi).name, err.message);
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
        traceTime = trace(:, 1);
        rawTime = normalizeTime(raw, traceTime, timeReference);
        if isempty(rawTime)
            continue;
        end

        lla = trace(:, 2:4);

        idx = numel(rawItems) + 1;
        rawItems(idx).id = getCharField(raw, 'id', erase(files(fi).name, '.json'));
        rawItems(idx).source = getCharField(raw, 'source', sourceName);
        rawItems(idx).type = getCharField(raw, 'type', '');
        rawItems(idx).desc = getCharField(raw, 'desc', '');
        rawItems(idx).time_reference = timeReference;
        rawItems(idx).raw_time = rawTime(:);
        rawItems(idx).lla = lla;

        if ~strcmp(timeReference, 'sim_elapsed')
            startCandidate = min(rawTime);
            mapKey = rawItems(idx).source;
            if isKey(sourceStart, mapKey)
                sourceStart(mapKey) = min(sourceStart(mapKey), startCandidate);
            else
                sourceStart(mapKey) = startCandidate;
            end
        end
    end
end

for i = 1:numel(rawItems)
    item = rawItems(i);
    if strcmp(item.time_reference, 'sim_elapsed')
        simElapsed = item.raw_time;
    elseif isKey(sourceStart, item.source)
        simElapsed = item.raw_time - sourceStart(item.source);
    else
        continue;
    end

    [simElapsed, sortIdx] = sort(simElapsed);
    lla = item.lla(sortIdx, :);
    [simElapsed, uniqueIdx] = unique(simElapsed, 'stable');
    lla = lla(uniqueIdx, :);

    if isempty(simElapsed)
        continue;
    end

    idx = numel(targets) + 1;
    targets(idx).id = item.id;
    targets(idx).source = item.source;
    targets(idx).type = item.type;
    targets(idx).desc = item.desc;
    targets(idx).sim_elapsed = simElapsed(:);
    targets(idx).lla = lla;
    targets(idx).ecef = llaToEcefMeters(lla);
end

fprintf('[loadUnifiedTargets] %d targets loaded from %s\n', numel(targets), unifiedDir);
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
