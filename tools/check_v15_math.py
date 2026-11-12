"""Independent exhaustive checks of V15 original-service bound mathematics.

No MATLAB execution or 64-user performance claim. Includes common-beam receiver
choices, forced users, partial interference trees, interrupted pricing, signed
period margins, configuration LP duals, and original x branching.
"""
from itertools import product
from dataclasses import dataclass
import numpy as np
from scipy.optimize import linprog


@dataclass
class Block:
    beam: np.ndarray
    signal: np.ndarray
    noise: np.ndarray
    cross: np.ndarray  # user, beam, slot
    factor: np.ndarray
    capacity: int
    allowed: list
    forced: np.ndarray

    def exact(self, on, weights):
        rates = (self.factor * np.log1p(self.signal / (self.noise + self.cross[:, on].sum(axis=1)))).sum(axis=1)
        group = np.zeros(len(self.beam), bool)
        for b in np.flatnonzero(on):
            ids = self.allowed[b]
            winner = ids[np.argmax(weights[ids] * rates[ids])]
            group[winner] = True
        return float(weights @ (rates * group)), group, rates * group

    def bound(self, on, free, weights):
        # Independently check the same cardinality-conditioned optimism against
        # ALL actual completions below. Receiver minima can differ: only a UB.
        selected, remaining = np.flatnonzero(on), np.flatnonzero(free)
        a, nr = len(selected), len(remaining)
        mandatory = self.cross[:, selected].sum(axis=1)
        optional = self.cross[:, remaining].copy()
        for j, b in enumerate(remaining):
            optional[self.beam == b, j] = np.inf
        prefix = np.concatenate((np.zeros((len(weights), 1, self.signal.shape[1])), np.cumsum(np.sort(optional, axis=1), axis=1)), axis=1)
        upper = -np.inf
        for add in range(min(nr, self.capacity-a)+1):
            extra = np.zeros_like(mandatory)
            if add:
                extra[:] = prefix[:, add]
                future = np.isin(self.beam, remaining)
                extra[future] = prefix[future, add-1]
            rate = (self.factor * np.log1p(self.signal / (self.noise + mandatory + extra))).sum(axis=1)
            values = np.zeros(len(on))
            for b in np.concatenate((selected, remaining)):
                ids = self.allowed[b]
                values[b] = np.max(weights[ids] * rate[ids])
            upper = max(upper, values[selected].sum() + np.sort(values[remaining])[::-1][:add].sum())
        return upper

    def groups(self, fixed=None):
        k = len(self.beam)
        for bits in product((False, True), repeat=k):
            group = np.array(bits)
            active = np.flatnonzero(group)
            if len(active)>self.capacity or len(set(self.beam[active]))!=len(active):
                continue
            if fixed is not None and np.any((fixed != -1) & (group != fixed)):
                continue
            if np.any(~group[self.forced]):
                continue
            if any(i not in self.allowed[self.beam[i]] for i in active):
                continue
            on = np.isin(np.arange(len(self.allowed)), self.beam[active])
            rates = (self.factor * np.log1p(self.signal / (self.noise + self.cross[:, on].sum(axis=1)))).sum(axis=1)
            yield group, rates * group


def random_block(rng, capacity=3):
    k, b, h = 6, 4, 3
    beam = np.array([0, 0, 1, 2, 3, 3])
    cross = rng.uniform(.001, 1.3, (k, b, h))
    cross[np.arange(k), beam] = 0
    allowed = [np.flatnonzero(beam==bb) for bb in range(b)]
    forced = np.zeros(k, bool)
    if rng.random()<.5:
        i = int(rng.integers(k)); forced[i] = True; allowed[beam[i]] = np.array([i])
    return Block(beam, rng.uniform(.1, 9, (k, h)), rng.uniform(.2, 2, (k, h)),
                 cross, rng.uniform(.2, 1, (k, h)), capacity, allowed, forced)


def check_pricing(rng):
    checks = 0
    for _ in range(80):
        block = random_block(rng)
        w = rng.uniform(0, 3, len(block.beam))
        groups = list(block.groups())
        must = np.isin(np.arange(4), block.beam[block.forced])
        # Every ternary partial beam state, including branches never visited by
        # a particular incumbent heuristic, must bound all legal descendants.
        for ternary in product((-1, 0, 1), repeat=4):
            t = np.array(ternary); on, free = t==1, t==-1
            if np.any(~on[must]) or on.sum()>block.capacity:
                continue
            domain = [(g, a) for g, a in groups if
                      np.all(np.isin(np.arange(4), block.beam[g])[on]) and
                      not np.any(np.isin(np.arange(4), block.beam[g])[t==0])]
            if not domain:
                continue
            exact = max(w @ a for _, a in domain)
            upper = block.bound(on, free, w)
            assert upper >= exact-1e-10, (upper, exact)
            checks += 1
        optimum = max(w @ a for _, a in groups)
        root = (must, ~must)
        queue = [(block.bound(*root, w), *root)]
        best, old = block.exact(must, w)[0], np.inf
        while queue:
            queue.sort(key=lambda x: x[0]); upper, on, free = queue.pop()
            if upper > best+1e-11:
                best = max(best, block.exact(on, w)[0])
                if free.any() and on.sum()<block.capacity:
                    b = int(np.flatnonzero(free)[0])
                    for take in (True, False):
                        child_on, child_free = on.copy(), free.copy()
                        child_on[b], child_free[b] = take, False
                        ub = min(upper, block.bound(child_on, child_free, w))
                        queue.append((ub, child_on, child_free))
            interrupted_upper = max([best]+[x[0] for x in queue])
            assert best <= optimum+1e-10 and interrupted_upper >= optimum-1e-10
            assert interrupted_upper <= old+1e-10
            old = interrupted_upper
        assert abs(best-optimum)<1e-10
    return checks


def configuration_lp(groups, q, margin, floor=None, fixed=None):
    k, m = len(q), len(groups)
    columns, owners = [], []
    for b, domain in enumerate(groups):
        for g, a in domain:
            if fixed is not None and np.any((fixed[:, b] != -1) & (g != fixed[:, b])):
                continue
            columns.append(a/q); owners.append(b)
    if not columns or any(b not in owners for b in range(m)):
        return None
    a = np.array(columns).T; n = len(columns); fair = floor is None
    c = np.zeros(n+fair)
    if fair:
        c[-1] = -1
    else:
        c[:n] = -(q @ a)
    ae = np.zeros((m, n+fair)); ae[np.array(owners), np.arange(n)] = 1
    ai = np.zeros((k, n+fair)); ai[:, :n] = -a
    if fair:
        ai[:, -1] = 1
    result = linprog(c, A_ub=ai, b_ub=-margin/q-(0 if fair else floor),
                     A_eq=ae, b_eq=np.ones(m), bounds=(0, None), method='highs')
    if not result.success:
        return None
    value = -result.fun - (0 if fair else margin.sum())
    lam = -result.ineqlin.marginals
    return value, lam


def check_duals_and_branching(rng):
    checks = 0
    for _ in range(12):
        blocks = [random_block(rng, 3) for _ in range(2)]
        # Keep a positive fairness witness for conditional-throughput tests;
        # forced-user branch restrictions are covered independently above.
        for block in blocks:
            block.forced[:] = False
            block.allowed = [np.flatnonzero(block.beam==b) for b in range(4)]
        groups = [list(b.groups()) for b in blocks]
        q, margin = rng.uniform(.5, 2, 6), rng.uniform(0, .05, 6)
        schedules = []
        for combination in product(*groups):
            x = np.stack([g for g, _ in combination], axis=1)
            service = np.maximum(0, sum(a for _, a in combination)-margin)
            schedules.append((x, np.min(service/q), service.sum()))
        optimum = max(s[1] for s in schedules)
        assert optimum>0
        # Any nonnegative multiplier vector gives an upper after pricing;
        # fairness uses the auxiliary-cap correction if lambda sum < 1.
        cap = min(sum(np.max(np.array([a for _, a in domain]), axis=0) for domain in groups)/q)
        for _ in range(12):
            lam = rng.uniform(0, .2, 6)
            h = sum(max((lam/q) @ a for _, a in domain) for domain in groups)
            u = max(0, cap*max(0, 1-lam.sum())+h-lam @ (margin/q))
            assert u >= optimum-1e-9
            checks += 1
        for floor in (None, optimum*.7, optimum*.9):
            exact = max(s[1] if floor is None else s[2] for s in schedules if floor is None or s[1]>=floor)
            root = configuration_lp(groups, q, margin, floor)
            assert root and root[0]>=exact-1e-8
            lam = root[1]; w = lam/q+(0 if floor is None else 1)
            dual = sum(max(w @ a for _, a in domain) for domain in groups)-lam @ (margin/q+(0 if floor is None else floor))
            if floor is not None:
                dual -= margin.sum()
            assert dual>=exact-1e-8 and abs(dual-root[0])<1e-7
            # Full configuration LP at every ORIGINAL x branch. Check local
            # bounds against independent original schedules, not just the root.
            for _ in range(8):
                fixed = rng.choice((-1, 0, 1), size=(6, 2), p=(.7, .15, .15))
                candidates = [s for s in schedules if np.all((fixed==-1) | (fixed==s[0])) and (floor is None or s[1]>=floor)]
                relaxed = configuration_lp(groups, q, margin, floor, fixed)
                if candidates:
                    val = max(s[1] if floor is None else s[2] for s in candidates)
                    if floor is None and val==0:
                        # G=[A-c]+ admits zero-fairness schedules even if the
                        # signed-service LP is infeasible. V15 explicitly takes
                        # max(0, dual upper) and never infers hard infeasibility
                        # from positive artificial deficits.
                        assert relaxed is None or max(0, relaxed[0])>=val-1e-8
                    else:
                        assert relaxed and relaxed[0]>=val-1e-8
                checks += 1
    return checks


if __name__ == '__main__':
    rng = np.random.default_rng(15023)
    pricing = check_pricing(rng)
    duals = check_duals_and_branching(rng)
    print(f'PASS: {pricing} partial common-beam domains; 80 interrupted/exhaustive pricing trees; {duals} dual and original-x branch checks.')
    print('Independent Python/SciPy mathematics checks only; not MATLAB execution or 64-user gap/performance validation.')
