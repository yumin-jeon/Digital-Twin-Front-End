function targetList = interpTargetPositions(targets, simElapsed)
%INTERPTARGETPOSITIONS Compute active target positions at simulation time.
%
% Returns targets active at the requested simulation elapsed time.

targetList = struct('id', {}, 'source', {}, 'type', {}, 'ecef', {}, 'lla', {});

for i = 1:numel(targets)
    tgt = targets(i);
    if isempty(tgt.sim_elapsed)
        continue;
    end

    if simElapsed < tgt.sim_elapsed(1) || simElapsed > tgt.sim_elapsed(end)
        continue;
    end

    idx = find(tgt.sim_elapsed <= simElapsed, 1, 'last');
    if idx >= numel(tgt.sim_elapsed)
        ecefInterp = tgt.ecef(end, :);
        llaInterp = tgt.lla(end, :);
    else
        t0 = tgt.sim_elapsed(idx);
        t1 = tgt.sim_elapsed(idx + 1);
        if t1 <= t0
            frac = 0.0;
        else
            frac = (simElapsed - t0) / (t1 - t0);
        end
        ecefInterp = tgt.ecef(idx, :) + frac .* (tgt.ecef(idx + 1, :) - tgt.ecef(idx, :));
        llaInterp = tgt.lla(idx, :) + frac .* (tgt.lla(idx + 1, :) - tgt.lla(idx, :));
    end

    j = numel(targetList) + 1;
    targetList(j).id = tgt.id;
    targetList(j).source = tgt.source;
    targetList(j).type = tgt.type;
    targetList(j).ecef = ecefInterp;
    targetList(j).lla = llaInterp;
end
end
