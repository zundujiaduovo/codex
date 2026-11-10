"""Independently audit V11 CSV pairing, schedules, QoS and recorded-time metrics.

Uses only the standard library. This checks export/statistic consistency, not a
second physical simulator or a proof of the numerical upper-bound algorithm.
Usage: python tools/validate_v11_exports.py results/v11_based_on_v10_paired
"""
from __future__ import annotations

import argparse
from bisect import bisect_right
import csv
import json
import math
from pathlib import Path
from statistics import mean


def read(directory, name):
    with (directory / name).open(encoding="utf-8") as stream:
        return list(csv.DictReader(stream))


def key(row):
    return row["method"], int(row["seed"])


def number(row, name):
    return float(row[name])


def close(actual, expected):
    if math.isnan(expected):
        assert math.isnan(actual), (actual, expected)
    else:
        assert math.isclose(actual, expected, rel_tol=1e-9, abs_tol=1e-7), (actual, expected)


def validate(directory):
    metadata = json.loads((directory / "experiment_protocol.json").read_text(encoding="utf-8"))
    protocol = metadata["protocol"]
    seeds, methods = protocol["seeds"], metadata["methods"]
    if not isinstance(seeds, list):
        seeds = [seeds]
    expected = {(method, seed) for seed in seeds for method in methods}
    rows = read(directory, "runs.csv")
    runs = {key(row): row for row in rows}
    assert len(runs) == len(rows) and set(runs) == expected
    shape, capacity = metadata["shape"], metadata["maxStreams"]
    users, groups, totals = {}, {}, {}
    for row in read(directory, "user_service.csv"):
        run = key(row)
        users.setdefault(run, []).append(row)
        totals[run] = totals.get(run, 0) + number(row, "serviceBits")
    for row in read(directory, "schedules.csv"):
        run = key(row)
        slot = int(row["user"]), int(row["resource"])
        cells = groups.setdefault(run, {})
        assert slot not in cells
        cells[slot] = row
    for run, row in runs.items():
        if row["status"] != "completed":
            continue
        assert len(users[run]) == shape[0]
        assert {int(r["user"]) for r in users[run]} == set(range(1, shape[0] + 1))
        close(totals[run], number(row, "totalBits"))
        full = all(number(r, "serviceBits") >= number(r, "targetBits") for r in users[run])
        assert full == bool(number(row, "fullQosFeasible"))
        assert len(groups[run]) == shape[0] * shape[1]
        for block in range(1, shape[1] + 1):
            active = [r for (u, m), r in groups[run].items() if m == block and int(r["selected"])]
            beams = [int(r["beam"]) for r in active]
            assert len(active) <= capacity and len(set(beams)) == len(active) and all(b > 0 for b in beams)
    upper = number(read(directory, "theoretical_bound_summary.csv")[0], "upperBits")
    traces = {}
    for row in read(directory, "search_checkpoints.csv"):
        if number(row, "fairness") >= 1 and math.isfinite(number(row, "seconds")):
            traces.setdefault(key(row), []).append((number(row, "seconds"), number(row, "totalBits")))
    for run, values in traces.items():
        ordered = {}
        for t, v in sorted(values, key=lambda point: point[0]):
            if t >= 0 and math.isfinite(v):
                ordered[t] = v
                assert v <= upper + 1e-8 * max(1, upper)
        traces[run] = (list(ordered), list(ordered.values()))

    def at(run, deadline):
        times, values = traces.get(run, ([], []))
        index = bisect_right(times, deadline) - 1
        return values[index] if index >= 0 else math.nan

    deadlines = {}
    for row in read(directory, "quality_at_deadlines.csv"):
        run, deadline = key(row), number(row, "deadlineSeconds")
        eligible = runs[run]["status"] == "completed" and number(runs[run], "fullQosFeasible") == 1
        value = at(run, deadline) if eligible and deadline <= protocol["budgetSeconds"] else math.nan
        close(number(row, "certifiedBits"), value)
        deadlines[run, deadline] = value
    for row in read(directory, "time_to_quality.csv"):
        run = key(row)
        times, values = traces.get(run, ([], []))
        eligible = runs[run]["status"] == "completed" and number(runs[run], "fullQosFeasible") == 1
        hits = [t for t, v in zip(times, values) if 100 * (1 - v / upper) <= number(row, "targetGapPercent") + 1e-12]
        hit = hits[0] if eligible and hits else math.nan
        close(number(row, "firstRecordedHitSeconds"), hit)
        assert bool(number(row, "hitWithinBudget")) == (hit <= protocol["budgetSeconds"])
    for row in read(directory, "performance_summary.csv"):
        run = key(row)
        if number(row, "fullQosFeasible") != 1 or not traces.get(run, ([], []))[0]:
            continue
        starts = [traces[peer][0][0] for peer in runs if peer[1] == run[1]
                  and runs[peer]["status"] == "completed" and number(runs[peer], "fullQosFeasible") == 1
                  and traces.get(peer, ([], []))[0]]
        start, end = max(starts), protocol["budgetSeconds"]
        close(number(row, "windowStartSeconds"), start)
        nodes = [start] + [t for t in traces[run][0] if start < t < end] + [end]
        area = sum((right - left) * max(0, 100 * (1 - at(run, left) / upper))
                   for left, right in zip(nodes, nodes[1:])) if start < end else math.nan
        close(number(row, "timeAverageGapPercent"), area / (end - start) if start < end else math.nan)
    differences = read(directory, "paired_differences.csv")
    assert len(differences) == 2 * len(seeds)
    seen = set()
    for row in differences:
        seed, baseline = int(row["seed"]), row["baseline"]
        assert (seed, baseline) not in seen
        seen.add((seed, baseline))
        a, b = runs["sb_v8_blockwise", seed], runs[baseline, seed]
        valid = all(r["status"] == "completed" and number(r, "fullQosFeasible") == 1 for r in (a, b))
        delta = number(a, "totalBits") - number(b, "totalBits") if valid else math.nan
        close(number(row, "deltaBits"), delta)
        close(number(row, "deltaBudgetBits"), deadlines[("sb_v8_blockwise", seed), protocol["budgetSeconds"]]
              - deadlines[(baseline, seed), protocol["budgetSeconds"]])
    for row in read(directory, "paired_statistics.csv"):
        values = [number(r, "deltaBits") for r in differences if r["baseline"] == row["baseline"]]
        values = [v for v in values if math.isfinite(v)]
        assert number(row, "availablePairs") == len(values)
        assert number(row, "missingPairs") == len(seeds) - len(values)
        close(number(row, "meanDeltaBits"), mean(values) if values else math.nan)
        wins = sum(v > protocol["tieToleranceBits"] for v in values)
        losses = sum(v < -protocol["tieToleranceBits"] for v in values)
        assert number(row, "wins") == wins and number(row, "losses") == losses
        assert number(row, "ties") == len(values) - wins - losses
        n = wins + losses
        p = min(1, 2 * sum(math.comb(n, k) for k in range(min(wins, losses) + 1)) / 2 ** n) if n else 1
        if values:
            close(number(row, "signTestTwoSidedP"), p)
    print(f"PASS: {len(seeds)} paired seeds, {len(runs)} runs; original schedule/QoS exports, pairing and recorded-time statistics consistent.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    validate(parser.parse_args().directory)
