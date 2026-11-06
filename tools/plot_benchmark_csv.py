"""Render published numeric CSV results when Octave has no graphics toolkit.

All model/search/metrics code runs in MATLAB/Octave; this optional helper only plots.
Usage: MPLCONFIGDIR=/tmp/leo-mpl python3 tools/plot_benchmark_csv.py results/benchmark_small
"""
import argparse
import csv
from pathlib import Path
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

LABELS = {
    'initial':'Common initialization', 'original_greedy':'Original: deficit greedy',
    'original_exchange':'Original: feasible exchanges', 'original_tabu':'Original: tabu search',
    'price_sb':'Lagrangian + SB', 'price_local':'Lagrangian + local search',
    'price_miqp':'Lagrangian + MIQP', 'proxy_milp':'Direct surrogate MILP',
    'sb_zero':'SB: zero tangent', 'sb_minimax_fixed':'SB: fixed minimax tangent',
    'sb_current_fixed':'SB: fixed touching tangent', 'sb_reference_portfolio':'SB: three-reference portfolio',
}

def main(directory):
    with (directory/'summary.csv').open(newline='') as f:
        all_rows = list(csv.DictReader(f))
    rows = [r for r in all_rows if int(r['completed'])>0]
    with (directory/'runs.csv').open(newline='') as f:
        runs = list(csv.DictReader(f))
    budget = float(runs[0]['budgetSeconds'])
    y = np.arange(len(rows)); labels = [LABELS.get(r['method'],r['method']) for r in rows]
    colors = ['#1678aa' if r['method']=='price_sb' else '#7e9cae' for r in rows]
    panels = [('medianFairness',1,'Capped minimum QoS ratio'),
              ('medianTotalBits',1e-6,'Original net service (Mbit)'),
              ('medianEndToEndSeconds',1,'Accounted end-to-end time (s)'),
              ('medianQosSatisfactionRate',100,'Users meeting QoS (%)')]
    fig, axes = plt.subplots(2,2,figsize=(17,12),layout='constrained')
    for ax,(field,scale,title) in zip(axes.flat,panels):
        values = np.array([float(r[field])*scale for r in rows])
        ax.barh(y,values,color=colors,height=.65)
        ax.set_yticks(y,labels); ax.invert_yaxis(); ax.set_title(title,fontweight='bold')
        ax.grid(axis='x',alpha=.22); ax.set_axisbelow(True)
        ax.spines[['right','top']].set_visible(False)
        for i,v in enumerate(values):
            ax.annotate(f'{v:.6g}',(v,i),xytext=(4,0),textcoords='offset points',va='center',fontsize=8)
        ax.set_xlim(0,max(max(values)*1.28,1e-8))
        if field=='medianEndToEndSeconds':
            ax.axvline(budget,color='#a24535',ls='--',lw=1,label=f'{budget:g} s soft budget')
            ax.legend(loc='lower right',fontsize=8)
        if field=='medianQosSatisfactionRate': ax.set_xlim(0,105)
    skipped = [LABELS.get(r['method'],r['method']) for r in all_rows if int(r['completed'])==0]
    n_seeds = len({r['seed'] for r in runs})
    note = f'{directory.name}: medians over {n_seeds} algorithm seeds; one fixed physical sample'
    if skipped: note += '\nUnavailable/failed (excluded from bars): '+', '.join(skipped)
    fig.suptitle(note,fontsize=13)
    fig.savefig(directory/'comparison.png',dpi=160)
    fig.savefig(directory/'comparison.pdf')
    plt.close(fig)
    exact = [float(r['medianExactFairnessGap']) for r in rows]
    if all(np.isfinite(exact)):
        fig,ax = plt.subplots(figsize=(10,6),layout='constrained')
        ax.barh(y,exact,color=colors); ax.set_yticks(y,labels); ax.invert_yaxis()
        ax.set_xlabel('Original fairness gap to complete exhaustive optimum')
        ax.set_title('Small case: exact fairness gaps (median)')
        ax.grid(axis='x',alpha=.25); ax.set_axisbelow(True)
        fig.savefig(directory/'exact_fairness_gap.png',dpi=160)
        fig.savefig(directory/'exact_fairness_gap.pdf')
        plt.close(fig)
    print(f'Plots written to {directory}')

if __name__ == '__main__':
    parser = argparse.ArgumentParser(); parser.add_argument('directory',type=Path)
    main(parser.parse_args().directory)
