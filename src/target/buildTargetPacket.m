function packet = buildTargetPacket(targets, simElapsed, sampleOffsets)
%BUILDTARGETPACKET Build target_out.json payload for Cesium target layering.

if nargin < 3 || isempty(sampleOffsets)
    sampleOffsets = 0:2;
end

sampleWindow = simElapsed + sampleOffsets(:)';

packet = struct();
packet.type = 'target_update';
packet.sim_elapsed = simElapsed;
packet.scenario_elapsed = simElapsed;
packet.sample_window = sampleWindow;

targetCells = {};
for i = 1:numel(targets)
    tgt = targets(i);
    samples = buildSamples(tgt, sampleWindow);
    if isempty(samples)
        continue;
    end

    item = struct();
    item.id = tgt.id;
    item.source = tgt.source;
    item.category = tgt.category;
    item.type = tgt.type;
    item.samples = num2cell(samples);

    targetCells{end + 1} = item; %#ok<AGROW>
end

packet.target_count = numel(targetCells);
packet.targets = targetCells;
end

function samples = buildSamples(tgt, sampleWindow)
samples = struct('scenario_elapsed', {}, 'position_ecef', {}, 'velocity_ecef', {});

if isempty(tgt.scenario_elapsed)
    return;
end

for si = 1:numel(sampleWindow)
    sampleTime = sampleWindow(si);
    if sampleTime < tgt.scenario_elapsed(1) || sampleTime > tgt.scenario_elapsed(end)
        continue;
    end

    [positionEcef, velocityEcef] = interpolateState(tgt, sampleTime);

    idx = numel(samples) + 1;
    samples(idx).scenario_elapsed = sampleTime;
    samples(idx).position_ecef = positionEcef;
    samples(idx).velocity_ecef = velocityEcef;
end
end

function [positionEcef, velocityEcef] = interpolateState(tgt, sampleTime)
idx = find(tgt.scenario_elapsed <= sampleTime, 1, 'last');

if idx >= numel(tgt.scenario_elapsed)
    positionEcef = tgt.position_ecef(end, :);
    velocityEcef = tgt.velocity_ecef(end, :);
    return;
end

t0 = tgt.scenario_elapsed(idx);
t1 = tgt.scenario_elapsed(idx + 1);
if t1 <= t0
    frac = 0.0;
else
    frac = (sampleTime - t0) / (t1 - t0);
end

positionEcef = tgt.position_ecef(idx, :) + frac .* (tgt.position_ecef(idx + 1, :) - tgt.position_ecef(idx, :));
velocityEcef = tgt.velocity_ecef(idx, :) + frac .* (tgt.velocity_ecef(idx + 1, :) - tgt.velocity_ecef(idx, :));
end
