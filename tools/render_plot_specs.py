"""Render MATLAB-exported plot_specs.json when the cloud has no graphics toolkit.

All metrics, aggregation, bounds, and plot selection are defined in MATLAB.
This program only renders those specifications. No solver or statistical estimates.
Usage: python tools/render_plot_specs.py results/plots_small/plot_specs.json
"""
from __future__ import annotations

import argparse
import json
import textwrap
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages
import numpy as np

METHODS = ["Initial", "Greedy", "Exchange", "Tabu", "Price+SB", "Price+Local",
           "Price+MIQP", "Proxy MILP", "SB: zero", "SB: minimax", "SB: current", "SB: portfolio"]
COLORS = ["#8492a6", "#b89032", "#20a387", "#2878b5", "#d73058", "#7841a4",
          "#ab7b58", "#5d707a", "#e58632", "#417b5a", "#5e74bd", "#b04b98"]
FIELD_LABELS = {
    "priceRounds1": "Phase 1", "priceRounds2": "Phase 2", "searchSteps1": "Phase 1",
    "searchSteps2": "Phase 2", "nodes1": "Phase 1", "nodes2": "Phase 2",
    "commonSeconds": "Common physical/model setup", "proxyPreparationSeconds": "Prebuilt proxy",
    "searchSeconds": "Search incl. internal setup", "recoveryEvaluations": "All recovery evaluations",
    "crossEvaluations": "Cross-block subset", "complete": "Complete", "partial": "Partial",
}


def items(value):
    """MATLAB JSON represents a singleton struct as an object, not an array."""
    if isinstance(value, dict):
        return [value]
    return value or []


def vec(value):
    return np.asarray(value, dtype=float).reshape(-1)


def color(name, index):
    if name == 'Tabu':
        return '#00804d'
    if name == 'Greedy':
        return '#1aa6a6'
    if name == 'SB':
        return '#d92633'
    if name == 'Local' or name == 'SB minus local_v8_blockwise':
        return '#3373d9'
    if name == 'SB minus original_tabu':
        return '#00804d'
    if name in {'sb_v8_blockwise', 'sb_v12_lexicographic'}:
        return '#d92633'
    if name in {'local_v8_blockwise', 'local_v12_lexicographic'}:
        return '#3373d9'
    modern = ['initial', 'original_exchange', 'original_tabu', 'original_tabu_independent',
              'price_sb_blockwise', 'price_local_blockwise', 'price_sb_joint', 'price_local_joint']
    modern_colors = ['#737373', '#1f66bf', '#00804d', '#1aa6a6', '#d92633', '#e68c0d', '#8c33b3', '#996633']
    if 'Verified lower' in name:
        return '#666666'
    if name in modern:
        return modern_colors[modern.index(name)]
    return COLORS[METHODS.index(name)] if name in METHODS else COLORS[index % len(COLORS)]


def draw_panel(fig, ax, panel):
    kind = panel["kind"]
    series = items(panel["series"])
    has_values = False
    if kind == "heatmap":
        z = np.asarray(panel["z"], dtype=float)
        if z.size:
            z = z.reshape(tuple(panel["zShape"]))
            clim = panel["clim"]
            im = ax.imshow(z, aspect="auto", interpolation="nearest", cmap="viridis",
                           vmin=clim[0] if len(clim) else None, vmax=clim[1] if len(clim) else None,
                           extent=(.5, z.shape[1]+.5, z.shape[0]+.5, .5))
            fig.colorbar(im, ax=ax, shrink=.83, pad=.02)
            has_values = bool(np.isfinite(z).any())
            for dim in ("x", "y"):
                labels = panel[f"{dim}labels"]
                if labels:
                    getattr(ax, f"set_{dim}ticks")(np.arange(1, len(labels)+1), labels, fontsize=8)
                else:
                    size = z.shape[1 if dim == "x" else 0]
                    if size <= 12:
                        getattr(ax, f"set_{dim}ticks")(np.arange(1, size+1))
                    else:
                        getattr(ax, f"{dim}axis").set_major_locator(matplotlib.ticker.MaxNLocator(integer=True, nbins=8))
    elif kind in {"bar", "categorical_line"}:
        styles = ["-o", "--s", "-.^", ":d"]
        for j, s in enumerate(series):
            x, y = vec(s["x"]), vec(s["y"])
            c = color(s['name'], j)
            style = ':' if 'independent' in s['name'] else '--' if 'local' in s['name'].lower() else '-'
            ax.plot(x, y, linestyle=style, marker=['o','s','^','d'][j % 4], color=c, linewidth=1.5, markersize=4,
                    label=FIELD_LABELS.get(s["name"], s["name"]), zorder=3)
            if np.asarray(s["low"]).size:
                lo, hi = vec(s["low"]), vec(s["high"])
                finite = np.isfinite(y) & np.isfinite(lo) & np.isfinite(hi)
                if finite.any():
                    ax.errorbar(x[finite], y[finite], yerr=np.maximum(0, [y[finite]-lo[finite], hi[finite]-y[finite]]),
                                fmt="none", color="#283343", capsize=3, linewidth=.9, zorder=4)
            has_values |= bool(np.isfinite(y).any())
        labels = panel["labels"]
        ax.set_xticks(np.arange(1, len(labels)+1), labels, rotation=35, ha="right", fontsize=8)
        if len(labels):
            ax.set_xlim(.4, len(labels)+.6)
        if has_values:
            # Mark individual missing entries; missing data must not look like zero-height bars.
            all_values = np.vstack([vec(s["y"]) for s in series])
            for x, missing in zip(vec(series[0]["x"]), ~np.isfinite(all_values).any(axis=0)):
                if missing:
                    ax.text(x, .03, "N/A", transform=ax.get_xaxis_transform(), ha="center", fontsize=7, color="#738095")
    else:
        for j, s in enumerate(series):
            x, y = vec(s["x"]), vec(s["y"])
            c = color(s["name"], j)
            if kind == "scatter":
                ax.scatter(x, y, color=c, s=33, alpha=.8, label=s["name"], marker=["o", "s", "^", "D"][j % 4], zorder=3)
            else:
                options = {"drawstyle": "steps-post"} if kind == "step" else {}
                ax.plot(x, y, color=c, linewidth=1.7 if s["name"] == "Price+SB" else 1.2,
                        label=s["name"], marker="o" if np.sum(np.isfinite(x) & np.isfinite(y)) < 3 else None, markersize=4,
                        linestyle=':' if ('independent' in s['name'] or 'Verified lower' in s['name'])
                        else '--' if 'local' in s['name'].lower() else '-', **options)
            has_values |= bool(np.isfinite(y).any())
        if panel["xlabels"]:
            ax.set_xticks(np.arange(1, len(panel["xlabels"])+1), panel["xlabels"], fontsize=8)
        elif "Price round" in panel["xlabel"] and series:
            steps = np.unique(np.concatenate([vec(s["x"]) for s in series]))
            if steps.size <= 12:
                ax.set_xticks(steps)
            else:
                ax.xaxis.set_major_locator(matplotlib.ticker.MaxNLocator(integer=True, nbins=8))
    if not has_values:
        ax.text(.5, .5, panel.get('emptyMessage') or "Not applicable / not reported", transform=ax.transAxes,
                ha="center", va="center", color="#738095", fontsize=10)
        if kind in {"bar", "categorical_line"}:
            ax.set_ylim(0, 1)
            ax.set_yticks([])
    if np.asarray(panel["reference"]).size:
        ax.axhline(float(panel["reference"]), color="#2c3544", ls="--", lw=1,
                   label=panel["referenceLabel"] or "Reference")
    if panel["ylim"]:
        ax.set_ylim(panel["ylim"])
    if panel.get('xlim'):
        ax.set_xlim(panel['xlim'])
    ax.set_title(textwrap.fill(panel["title"], width=66), fontsize=11, loc="left", fontweight="semibold", pad=10)
    ax.set_xlabel(panel["xlabel"], fontsize=9)
    ax.set_ylabel(panel["ylabel"], fontsize=9)
    ax.tick_params(labelsize=8)
    if kind != "heatmap":
        ax.grid(axis="y", color="#e6eaf0", lw=.7, zorder=0)
        ax.set_axisbelow(True)
        ax.spines[["top", "right"]].set_visible(False)
        ax.ticklabel_format(axis="y", style="sci", scilimits=(-3, 5))
    handles, labels = ax.get_legend_handles_labels()
    if has_values and (len(handles) > 1 or panel["referenceLabel"]):
        ax.legend(fontsize=7, framealpha=.85, ncol=2 if len(handles) > 5 else 1)
    # Long methodological notes stay in the JSON and documentation; avoid covering data/titles.


def render(source: Path, directory: Path):
    specs = items(json.loads(source.read_text(encoding="utf-8")))
    directory.mkdir(parents=True, exist_ok=True)
    plt.rcParams.update({"font.family": "DejaVu Sans", "figure.facecolor": "white", "axes.facecolor": "white",
                         "pdf.fonttype": 42, "ps.fonttype": 42})
    with PdfPages(directory / "all_figures.pdf") as bundle:
        for spec in specs:
            nrows, ncols = int(spec["rows"]), int(spec["cols"])
            fig, axes = plt.subplots(nrows, ncols, figsize=(7.2*ncols, 4.5*nrows+.6),
                                     squeeze=False, layout="constrained")
            for ax, p in zip(axes.flat, items(spec["panels"])):
                draw_panel(fig, ax, p)
            for ax in list(axes.flat)[len(items(spec["panels"])):]:
                ax.set_visible(False)
            fig.suptitle(spec["title"], fontsize=13, fontweight="semibold")
            fig.savefig(directory / f'{spec["name"]}.png', dpi=150, bbox_inches="tight", pad_inches=.15)
            fig.savefig(directory / f'{spec["name"]}.pdf', bbox_inches="tight", pad_inches=.15)
            bundle.savefig(fig, bbox_inches="tight", pad_inches=.15)
            plt.close(fig)
    # A compact visual index; individual figures contain the legible detail.
    ncols = 3
    nrows = (len(specs)+ncols-1)//ncols
    fig, axes = plt.subplots(nrows, ncols, figsize=(18, 3.8*nrows), squeeze=False, layout="constrained")
    for ax, spec in zip(axes.flat, specs):
        ax.imshow(plt.imread(directory / f'{spec["name"]}.png'))
        ax.set_title(spec["name"].replace("_", " "), fontsize=10)
        ax.axis("off")
    for ax in list(axes.flat)[len(specs):]:
        ax.axis("off")
    fig.savefig(directory / "overview.png", dpi=140)
    plt.close(fig)
    links = ["# 图表索引", "", "数值和图形规格由 MATLAB 生成；本目录图像使用 Matplotlib 渲染。", "",
             "[全部图表 PDF](all_figures.pdf) · [总览](overview.png)", "",
             "数值含义、聚合方式和代表种子以各图标题及 JSON 规格为准；V12 六联图固定取第一个请求的种子。", "",
             "NaN / N/A 表示不适用或未报告；迭代计数的单位详见项目 PLOTS.md。", ""]
    for spec in specs:
        links.append(f'- {spec["name"]}: [PNG]({spec["name"]}.png) · [PDF]({spec["name"]}.pdf)')
    (directory / "INDEX.md").write_text("\n".join(links)+"\n", encoding="utf-8")
    print(f"Rendered {len(specs)} figures, PDF bundle and overview in {directory}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("--directory", type=Path)
    args = parser.parse_args()
    render(args.source, args.directory or args.source.parent)
