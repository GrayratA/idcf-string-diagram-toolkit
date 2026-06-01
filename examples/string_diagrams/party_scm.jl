using Catlab
using Catlab.Theories
using Catlab.Programs

@present PartySCM(FreeCartesianCategory) begin
    (A, B, C, S, UA, UB, UC, US)::Ob
    f_A::Hom(UA, A)
    f_B::Hom(A ⊗ UB, B)
    f_C::Hom(A ⊗ UC, C)
    f_S::Hom(B ⊗ C ⊗ US, S)
    PU_A::Hom(munit(), UA)
    PU_B::Hom(munit(), UB)
    PU_C::Hom(munit(), UC)
    PU_S::Hom(munit(), US)
end

base_wd = @program PartySCM () begin
    u_a = PU_A()
    a = f_A(u_a)

    u_b = PU_B()
    b = f_B(a, u_b)

    u_c = PU_C()
    c = f_C(a, u_c)

    u_s = PU_S()
    s = f_S(b, c, u_s)

    return b, s
end

(
    name="party_scm",
    input=base_wd,
    display_syms=[:B, :S],
    output_vars=["S"],
)
