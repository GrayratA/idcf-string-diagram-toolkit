using Catlab
using Catlab.Theories
using Catlab.Programs

@present ReviewerCommuteSCM(FreeCartesianCategory) begin
    (W, T, M, L, Y, R1, UW, UT, UM, UL, UY, UR1)::Ob
    f_W::Hom(UW, W)
    f_T::Hom(W ⊗ R1 ⊗ UT, T)
    f_M::Hom(W ⊗ UM, M)
    f_L::Hom(T ⊗ M ⊗ UL, L)
    f_Y::Hom(L ⊗ R1 ⊗ UY, Y)
    f_R1::Hom(UR1, R1)
    PU_W::Hom(munit(), UW)
    PU_T::Hom(munit(), UT)
    PU_M::Hom(munit(), UM)
    PU_L::Hom(munit(), UL)
    PU_Y::Hom(munit(), UY)
    PU_R1::Hom(munit(), UR1)
end

base_wd = @program ReviewerCommuteSCM () begin
    u_w = PU_W()
    w = f_W(u_w)

    u_r1 = PU_R1()
    r1 = f_R1(u_r1)

    u_t = PU_T()
    t = f_T(w, r1, u_t)

    u_m = PU_M()
    m = f_M(w, u_m)

    u_l = PU_L()
    l = f_L(t, m, u_l)

    u_y = PU_Y()
    y = f_Y(l, r1, u_y)

    return w, t, m, l, y
end

(
    name="commute_scm",
    input=to_hom_expr(FreeCartesianCategory, base_wd),
    display_syms=[:W, :T, :M, :L, :Y],
    output_vars=["Y"],
)
