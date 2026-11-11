"""Independent enumeration oracle for V14 bound algebra and bounded slack.

This checks the mathematical construction with SciPy, not MATLAB execution or
64-user performance. Run: python tools/check_v14_math.py
"""
from itertools import combinations, product
import numpy as np
from scipy.optimize import linprog


def instance(rng):
    k, m, capacity = 4, 2, 2
    signal = rng.uniform(.5, 5, (k, m))
    noise = rng.uniform(.2, 1, (k, m))
    cross = rng.uniform(.01, .8, (m, k, k))
    for b in range(m):
        np.fill_diagonal(cross[b], 0)
    margin = rng.uniform(0, .1, k)
    imax = np.max(cross, axis=2).T  # L-1=1 other interferer.
    r0 = np.log2(1 + signal / noise)
    rend = np.log2(1 + signal / (noise + imax))
    omega = (r0 - rend) / imax
    groups = []
    for size in range(capacity + 1):
        for ids in combinations(range(k), size):
            x = np.zeros(k)
            x[list(ids)] = 1
            groups.append(x)
    schedules, services = [], []
    for left, right in product(groups, repeat=m):
        x = np.stack((left, right), axis=1)
        rates = np.column_stack([
            x[:, b] * np.log2(1 + signal[:, b] / (noise[:, b] + cross[b] @ x[:, b]))
            for b in range(m)
        ])
        schedules.append(x)
        services.append(np.maximum(0, rates.sum(axis=1) - margin))
    return k, m, capacity, r0, omega, cross, margin, schedules, np.array(services)


def relaxation(case, floor=None):
    k, m, cap, a, omega, cross, margin, schedules, services = case
    pairs = [(i, j, b) for b in range(m) for i, j in combinations(range(k), 2)]
    nx, npairs = k * m, len(pairs)
    fair = floor is None
    n = nx + npairs + int(fair)
    d = np.zeros((k, n))
    for b in range(m):
        for i in range(k):
            d[i, b*k+i] = a[i, b]
    for p, (i, j, b) in enumerate(pairs):
        d[i, nx+p] = -omega[i, b] * cross[b, i, j]
        d[j, nx+p] = -omega[j, b] * cross[b, j, i]
    rows, rhs = [], []

    def add(row, value):
        rows.append(row)
        rhs.append(value)

    for b in range(m):
        row = np.zeros(n)
        row[b*k:(b+1)*k] = 1
        add(row, cap)
    for p, (i, j, b) in enumerate(pairs):
        xi, xj, y = b*k+i, b*k+j, nx+p
        for x in (xi, xj):
            row = np.zeros(n)
            row[y], row[x] = 1, -1
            add(row, 0)
        row = np.zeros(n)
        row[xi], row[xj], row[y] = 1, 1, -1
        add(row, 1)
    for i in range(k):
        row = -d[i].copy()
        if fair:
            row[-1] = 1
        add(row, -margin[i] - (0 if fair else floor))
    for b in range(m):
        for i in range(k):
            upper, lower = np.zeros(n), np.zeros(n)
            upper[b*k+i] = -(cap-1)
            lower[b*k:(b+1)*k] = 1
            lower[b*k+i] += cap-1
            for p, (left, right, resource) in enumerate(pairs):
                if resource == b and i in (left, right):
                    upper[nx+p] = 1
                    lower[nx+p] = -1
            add(upper, 0)
            add(lower, cap)
    c = np.zeros(n)
    if fair:
        c[-1] = 1
    else:
        c = d.sum(axis=0)
    bound = np.ones(n)
    if fair:
        bound[-1] = np.min(a.sum(axis=1)-margin)
    constant = 0 if fair else -margin.sum()
    aineq, bineq = np.array(rows), np.array(rhs)
    # Check that EVERY enumerated original feasible point embeds in the LP.
    for x, service in zip(schedules, services):
        if not fair and np.min(service) < floor-1e-12:
            continue
        z = list(x.T.reshape(-1)) + [x[i, b]*x[j, b] for i, j, b in pairs]
        if fair:
            if np.min(service) == 0:
                continue  # Positive-fairness reduction; zero optimum is handled separately.
            z.append(np.min(service))
        assert np.max(aineq @ z-bineq) < 1e-9
    result = linprog(-c, A_ub=aineq, b_ub=bineq, bounds=list(zip(np.zeros(n), bound)), method='highs')
    assert result.success, result.message
    exact = np.max(np.min(services, axis=1)) if fair else np.max(services[np.min(services, axis=1) >= floor-1e-12].sum(axis=1))
    assert -result.fun+constant >= exact-1e-9
    dual = np.maximum(0, -result.ineqlin.marginals)
    residual = c-aineq.T @ dual
    verified = bineq @ dual + np.maximum(residual, 0) @ bound + constant
    assert verified >= exact-1e-9
    return -result.fun+constant, exact


def main():
    for cap in range(1, 33):
        bits = int(np.ceil(np.log2(cap+1)))
        weights = [2**j for j in range(bits-1)]
        weights.append(cap-sum(weights))
        assert sum(weights) == cap
        for selected in range(cap+1):
            remaining = cap-selected
            encoded = np.zeros(bits)
            for j in np.argsort(-np.array(weights)):
                if remaining >= weights[j]:
                    encoded[j] = 1
                    remaining -= weights[j]
            assert remaining == 0 and selected+np.dot(weights, encoded) == cap
    rng = np.random.default_rng(71669974)
    checks = 0
    for _ in range(30):
        case = instance(rng)
        fairness_upper, fairness_exact = relaxation(case)
        loose, _ = relaxation(case, .5*fairness_exact)
        tight, _ = relaxation(case, fairness_exact)
        assert tight <= loose+1e-8
        checks += 3
    print(f'PASS: bounded slack for L=1..32; {checks} coupled LPs cover independently enumerated original optima; conditional LP values are monotone in the floor.')
    print('Scope: mathematical oracle only; this does not execute MATLAB or establish 64-user algorithm performance.')


if __name__ == '__main__':
    main()
