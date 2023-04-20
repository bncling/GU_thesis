import time

# computes degree of regularity for a homogeneous ideal
def hdegree_reg(I):
    G = I.groebner_basis()
    LT = Ideal([g.lt() for g in G])
    HS = hilbert_poincare_series(LT)
    delta = HS.numerator().degree()
    l = HS.denominator().degree()
    return(delta - l + 1)


# computes F^top
def f_top(I, R):
    f_list = I.gens()
    new_ring.<h> = PolynomialRing(R, order = 'degrevlex')
    homogenized = [new_ring(poly.homogenize()) for poly in f_list]
    final = [R(poly.subs(h=0)) for poly in homogenized] 
    return(final)


# computes degree of regularity in the nonhomogeneous case
def degree_reg(I, R):
    J = ideal(f_top(I,R))
    return hdegree_reg(J)


# checks if a polynomial f is a linear combination of rows of a degree d Macaulay matrix 
def test_rowsp(f, f_list, d, ring):
    mons = get_mons(d, ring)
    M = mac_matrix(f_list, d, ring)
    done = False
    while not done:
        rowsp = M.row_space()
        to_be_added = []
        for row in M.rref().rows():
            g = 0
            for (coeff, mon) in zip(row, mons):
                g += coeff * mon
            max_test_deg = d - g.degree()
            if (g != 0) and (max_test_deg > 0):
                for mon in get_mons(max_test_deg, ring):
                    test_p = mon*g
                    test_vec = vector([test_p.monomial_coefficient(moon) for moon in mons])
                    if test_vec not in rowsp:
                        to_be_added.append(test_vec)
        if to_be_added == []:
            done = True
        else:
            new_rows = M.rows() + to_be_added
            M = Matrix(new_rows)
    f_vec = vector([ring(f).monomial_coefficient(mon) for mon in mons])
    return f_vec in M.row_space()


# get the monomials in a ring up to a certain degree, or just of that degree
def get_mons(d, ring, leq = True):
    if leq:
        mons = []
        for i in range(d+1):
            mons += [ring({tuple(a):1}) for a in WeightedIntegerVectors(i,[1 for gen in ring.gens()])]
    else:
        mons = [ring({tuple(a):1}) for a in WeightedIntegerVectors(d,[1 for gen in ring.gens()])]
    mons.sort()
    mons.reverse()
    return mons


# compute the degree fall for a polynomial f with respect to an ideal generated by f_list
def deg_fall(f, f_list, ring):
    test_deg = f.degree()
    while True:
        print(test_deg, time.strftime("%H:%M:%S", time.localtime())) # can potentially take quite a while, test_rowsp() very slow
        if test_rowsp(f, f_list, test_deg, ring):
            return test_deg
        test_deg += 1
        

# compute the last fall degree of an ideal generated by f_list
def lfd(f_list, ring):
    fall_degrees = []
    I = ideal(f_list)
    B = I.groebner_basis()
    print(B)
    for f in B:
        print(f)
        d = deg_fall(f, f_list, ring)
        if d > f.degree():
            fall_degrees.append(d)
    if fall_degrees == []:
        return 0
    else:
        return max(fall_degrees)
    
    
# Compute the Macaulay matrix in degree d of a system f = [f1,...,fs]
def mac_matrix(f,d,ring):
    mons0 = monomials(list(ring.gens()), [d+1 for i in range(len(ring.gens()))])
    mons = []
    for mon in mons0:
        if mon.degree() <= d:
            mons.append(mon)
    mons.sort()
    mons.reverse() # for reasons I don't understand, the .sort() method respects the chosen order but reverses it
    col_labs = []
    for deg in range(d + 1):
        segment = []
        for poly in f:
            for mon in mons:
                label = ring(mon)*ring(poly)
                if label.degree() == deg:
                    segment.append(label)
        col_labs += segment
    return matrix([[label.monomial_coefficient(mon) for mon in mons] for label in col_labs])


# Takes an RREF Macaulay matrix as input and returns a list of the corresponding polynomials
def recover_polys(M, d, ring):
    mons0 = monomials(list(ring.gens()), [d+1 for i in range(len(ring.gens()))])
    mons = []
    for mon in mons0:
        if mon.degree() <= d:
            mons.append(mon)
    mons.sort()
    mons.reverse()
    B = []
    for row in M.rows():
        g = 0
        for (coeff,mon) in zip(row,mons):
            g += coeff*mon
        if g != 0:
            B.append(g)
    if B == []:
        B = [ring(0)]
    return Sequence(B) # Sage doesn't know how to work with the output list unless it is a "Sequence" of polynomials


# Now instead of using mac_matrix followed by recover_polys, we ask for the new polynomials directly:
def mac_basis(f,d,ring):
    mons0 = monomials(list(ring.gens()), [d+1 for i in range(len(ring.gens()))])
    mons = []
    for mon in mons0:
        if mon.degree() <= d:
            mons.append(mon)
    mons.sort()
    mons.reverse() # for reasons I don't understand, the .sort() method respects the chosen order but reverses it
    col_labs = []
    for deg in range(d + 1):
        segment = []
        for poly in f:
            for mon in mons:
                label = ring(mon)*ring(poly)
                if label.degree() == deg:
                    segment.append(label)
        col_labs += segment
    M = matrix([[label.monomial_coefficient(mon) for mon in mons] for label in col_labs]).rref()
    B = []
    for row in M.rows():
        g = 0
        for (coeff,mon) in zip(row,mons):
            g += coeff*mon
        if g != 0:
            B.append(g)
    if B == []:
        B = [ring(0)]
    return Sequence(B)


# Now define a function that calculates a Gröbner basis and the solving degree (per Caminata and Gorla, 2021)
def mac_grob(f,ring):
    test_deg = 0
    while True:
        B = mac_basis(f, test_deg, ring)
        print(test_deg, B, B.is_groebner(), ideal(B) == ideal(f))
        if B.is_groebner() and ideal(B) == ideal(f):
            return (test_deg,B)
        test_deg += 1
        

# Modified version to compute the solving degree per Caminata and Gorla, 2023
def sdeg(f, ring):
    d = 0
    while True:
        d_level_base = []
        mons = get_mons(d, ring)
        M = mac_matrix(f, d, ring)
        done = False
        while not done:
            rowsp = M.row_space()
            to_be_added = []
            for row in M.rref().rows():
                g = 0
                for (coeff, mon) in zip(row, mons):
                    g += coeff * mon
                max_test_deg = d - g.degree()
                if (g != 0) and (max_test_deg > 0):
                    for mon in get_mons(max_test_deg, ring):
                        test_p = mon*g
                        test_vec = vector([test_p.monomial_coefficient(moon) for moon in mons])
                        if test_vec not in rowsp:
                            to_be_added.append(test_vec)
            if to_be_added == []:
                done = True
                for row in M.rref().rows():
                    g = 0
                    for (coeff, mon) in zip(row, mons):
                        g += coeff * mon
                    if g != 0:
                        d_level_base.append(g)
                if d_level_base == []:
                    d_level_base = [ring(0)]
                check_1 = Sequence(d_level_base).is_groebner()
                check_2 = (ideal(d_level_base) == ideal(f))
                print(d, Sequence(d_level_base), check_1, check_2)
                if check_1 and check_2:
                    return (d, Sequence(d_level_base))
                d += 1
            else:
                new_rows = M.rows() + to_be_added
                M = Matrix(new_rows)


# compute the initial ideal of an ideal I
def intl(I, ring):
    G = I.groebner_basis()
    in_gens = []
    for gen in G:
        in_gens.append(gen.lt())
    return ideal(in_gens)


# compute the action of an invertible linear map on a single variable
def GL_variable_action(g, variable, ring):
    variables = ring.gens()
    n = len(variables)
    row_index = variables.index(variable)
    return sum([variables[i]*g[row_index][i] for i in range(n)])


# compute the action of an invertible linear map on a polynomial f
def GL_function_action(g, f, ring):
    variables = ring.gens()
    sub_dict = {var:GL_variable_action(g, var, ring) for var in variables}
    return f.subs(sub_dict)


# compute the action of an invertible linear map on an ideal I
def GL_action(g, I, ring):
    functions = I.gens()
    return ideal([GL_function_action(g, f, ring) for f in functions])


# get a "random" invertible matrix of a specified size over a specified field (random enough, anyway)
def random_GL(field, size):
    while True:
        M = random_matrix(QQ, size, size, num_bound = 1000, den_bound = 1).change_ring(field)
        if M.is_invertible():
            break
    return M


# apply a random invertible linear map to an ideal I
def apply_random_GL(I, ring):
    size = len(ring.gens())
    g = random_GL(ring.base_ring(), size)
    return GL_action(g, I, ring)


# attempt to compute the generic initial ideal n times
def attempt_gins(I, ring, n):
    candidates = [intl(apply_random_GL(I, ring), ring) for i in range(n)]
    return candidates


# same as above but only returns the result occuring the most times
def attempt_gin(I, ring, n):
    candidates = Counter()
    for i in range(n):
        print(i)
        cand = intl(apply_random_GL(I, ring), ring)
        candidates[cand] += 1
        clear_output()
    return max(dict(candidates), key=candidates.get)


# same as attempt_gins but this time check first if the ideal computed is Borel-fixed before adding it
def attempt_borel_gins(I, ring, n):
    candidates = []
    for i in range(n):
        cand = intl(apply_random_GL(I, ring), ring)
        if is_fixed(cand, ring):
            candidates.append(cand)
    return candidates


# check if an ideal is Borel-fixed
def is_fixed(I, ring, quiet = True):
    n = len(ring.gens())
    var_dict = dict(zip([i for i in range(n)], ring.gens()))
    for mon in I.gens():
        for i in range(n - 1):
            test_var = var_dict[i + 1]
            if test_var.divides(mon):
                new_mon = (mon / test_var) * var_dict[i]
                if new_mon not in I:
                    if not quiet:
                        print(mon, "is in the ideal, but", new_mon, "is not")
                    return False
    return True
    

# return the smallest Borel-fixed ideal containing a given ideal
def make_borel(I, ring):
    new_gens = []
    n = len(ring.gens())
    var_dict = dict(zip([i for i in range(n)], ring.gens()))
    for mon in I.gens():
        d = mon.degree()
        mons = [ring({tuple(a):1}) for a in WeightedIntegerVectors(d,[1 for gen in ring.gens()])]
        new_gens += mons[mons.index(mon):]
    return ideal(ideal(new_gens).groebner_basis())


# check if an ideal is generic in the sense of Bayer-Stillman
def is_generic(I,R):
    r = I.dimension()
    if r == 0: 
        return True
    r_gens = list(R.gens())
    M = ideal(r_gens)
    variables_to_check = r_gens[r-2:][::-1]
    variables_checked = []
    for variable in variables_to_check:
        J = I
        for var in variables_checked:
            J = J + ideal(var)
        if J.dimension() == 0:
            return True
        sat = J.saturation(M)[0]
        for prime in sat.associated_primes():
            if variable in prime:
                return False
        variables_checked.append(variable)
    return True




