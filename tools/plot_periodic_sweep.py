"""Plot saved periodic QoS experiments; no re-optimization or metric fitting.

Usage: python tools/plot_periodic_sweep.py results/periodic_qos_20261107
"""
import argparse
import csv
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np


def rows(path):
    with path.open() as stream:
        return list(csv.DictReader(stream))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    directory = parser.parse_args().directory
    loads = [1, 2, 4]
    methods = [("initial", "Initial", "#8492a6"),
               ("original_tabu", "Tabu", "#2878b5"),
               ("price_sb", "Price+SB", "#d73058"),
               ("price_local", "Price+Local", "#7841a4")]
    records = {load: rows(directory / f"load_{load}_Mbit" / "runs.csv") for load in loads}
    validation = {load: rows(directory / f"load_{load}_Mbit" / "independent_validation.csv") for load in loads}
    fig, axes = plt.subplots(2, 2, figsize=(11, 7), layout="constrained")
    metrics = [("fairness", 1, "Certified minimum QoS ratio", "Ratio"),
               ("totalBits", 1e-6, "Certified sum service / 1 s", "Mbps"),
               ("qosSatisfactionRate", 100, "Users with certified full QoS", "Percent")]
    for ax, (field, scale, title, ylabel) in zip(axes.flat, metrics):
        for method, label, color in methods:
            groups = [[float(row[field]) * scale for row in records[load]
                       if row["method"] == method and row["status"] == "completed"] for load in loads]
            middle = np.array([np.median(group) for group in groups])
            limits = np.array([[mid - min(group) for mid, group in zip(middle, groups)],
                               [max(group) - mid for mid, group in zip(middle, groups)]])
            ax.errorbar(loads, middle, yerr=limits, marker="o", capsize=3, label=label, color=color)
        ax.set(title=title + "\nMedian and min-max, 3 optimizer seeds", ylabel=ylabel)
    ax = axes.flat[3]
    for method, label, color in methods:
        values = [float(next(row for row in validation[load] if row["method"] == method)["mcMeanTotalMbit"])
                  for load in loads]
        ax.plot(loads, values, marker="o", color=color, label=label)
    ax.set(title="Mean throughput under fresh fading\nFirst optimizer seed; 2000 periods", ylabel="Mbps")
    for ax in axes.flat:
        ax.set_xlabel("Demand per user (Mbit / 1 s period)")
        ax.set_xticks(loads)
        ax.grid(alpha=.2)
    axes[0, 0].set_ylim(0, 1.05)
    axes[1, 0].set_ylim(-3, 103)
    axes[0, 0].legend(fontsize=8)
    fig.suptitle("Fixed 32 users, 20 MHz, 80 W; periodic reliability model\n12 s soft budget per method; certified service and sampled throughput are distinct", fontsize=13)
    for extension in ["png", "pdf"]:
        fig.savefig(directory / f"load_comparison.{extension}", dpi=180)
    plt.close(fig)


if __name__ == "__main__":
    main()
