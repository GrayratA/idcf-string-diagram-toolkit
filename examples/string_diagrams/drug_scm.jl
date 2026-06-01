using Catlab
using Catlab.Theories
using Catlab.Programs

@present ReviewerDrugSCM(FreeCartesianCategory) begin
    (X, W, D, Z, Y, R1, UX, UW, UD, UZ, UY, UR1)::Ob
    f_X::Hom(R1 ⊗ UX, X)
    f_W::Hom(X ⊗ UW, W)
    f_D::Hom(UD, D)
    f_Z::Hom(D ⊗ UZ, Z)
    f_Y::Hom(W ⊗ Z ⊗ R1 ⊗ UY, Y)
    f_R1::Hom(UR1, R1)
    PU_X::Hom(munit(), UX)
    PU_W::Hom(munit(), UW)
    PU_D::Hom(munit(), UD)
    PU_Z::Hom(munit(), UZ)
    PU_Y::Hom(munit(), UY)
    PU_R1::Hom(munit(), UR1)
end

base_wd = @program ReviewerDrugSCM () begin
    u_r1 = PU_R1()
    r1 = f_R1(u_r1)

    u_x = PU_X()
    x = f_X(r1, u_x)

    u_w = PU_W()
    w = f_W(x, u_w)

    u_d = PU_D()
    d = f_D(u_d)

    u_z = PU_Z()
    z = f_Z(d, u_z)

    u_y = PU_Y()
    y = f_Y(w, z, r1, u_y)

    return d, z, x, w, y
end

(
    name="drug_scm",
    input=to_hom_expr(FreeCartesianCategory, base_wd),
    display_syms=[:D, :Z, :X, :W, :Y],
    output_vars=["Y"],
)
