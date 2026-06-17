# Correctness differential test: toolkit vs cfid

Each case is a counterfactual identification problem. The toolkit's ID/FAIL verdict is compared against the cfid reference implementation.

## Summary

| metric | value |
| --- | --- |
| total cases | 310 |
| comparable (both gave a verdict) | 310 |
| **agree** | **308** |
| **disagree** | **2** |
| not comparable (≥1 ERROR) | 0 |
| agreement rate | 99.4% |

## ❌ Disagreements (investigate these)

| case | toolkit | cfid | query |
| --- | --- | --- | --- |
| rand0048 | FAIL | ID | P(V8=v8 ∣ do(V1=v1) ∣ V2=v2 ∧ V5=v5) [interventions; 11→, 5↔] |
| rand0255 | FAIL | ID | P(V5=v5 ∣ do(V1=v1) ∣ V3=v3 ∣ do(V2=v2) ∧ V2=v2) [interventions; 6→, 2↔] |

## ✓ Agreements

| case | verdict | query |
| --- | --- | --- |
| drug | ID | P(Y=y ∣ do(X=x) ∣ X=xt ∧ Z=z ∣ do(D=d) ∧ D=d) [interventions; 4→, 1↔] |
| party | ID | P(S=s ∣ do(B=b) ∣ B=bp) [interventions; 4→, 0↔] |
| chain4 | FAIL | P(V4=v4 ∣ do(V1=v1) ∣ V3=v3 ∣ do(V2=v2) ∧ V2=v2) [interventions; 3→, 0↔] |
| fanin4 | FAIL | P(V4=v4 ∣ do(V1=v1) ∣ V2=v2 ∧ V3=v3) [interventions; 5→, 0↔] |
| chain_bi4 | FAIL | P(V4=v4 ∣ do(V1=v1) ∣ V3=v3 ∣ do(V2=v2) ∧ V2=v2) [interventions; 3→, 3↔] |
| dense4 | FAIL | P(V4=v4 ∣ do(V1=v1) ∣ V2=v2) [interventions; 2→, 0↔] |
| chain6 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V5=v5 ∣ do(V4=v4) ∧ V3=v3) [interventions; 5→, 0↔] |
| fanin6 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V3=v3 ∧ V5=v5) [interventions; 9→, 0↔] |
| chain_bi6 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V4=v4 ∧ V5=v5) [interventions; 5→, 5↔] |
| dense6 | ID | P(V5=v5 ∣ do(V1=v1) ∣ V2=v2 ∧ V6=v6) [interventions; 4→, 0↔] |
| rand0001 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V4=v4 ∣ do(V3=v3) ∧ V3=v3) [interventions; 9→, 1↔] |
| rand0002 | FAIL | P(V5=v5 ∣ do(V1=v1) ∣ V2=v2 ∧ V4=v4) [interventions; 8→, 0↔] |
| rand0003 | FAIL | P(V5=v5 ∣ do(V1=v1) ∣ V2=v2 ∧ V3=v3) [interventions; 6→, 2↔] |
| rand0004 | FAIL | P(V6=v6 ∣ do(V2=v2) ∣ V5=v5 ∣ do(V4=v4) ∧ V1=v1) [interventions; 6→, 1↔] |
| rand0005 | FAIL | P(V5=v5 ∣ do(V1=v1) ∣ V4=v4 ∧ V2=v2) [interventions; 6→, 1↔] |
| rand0006 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V5=v5 ∧ V2=v2) [interventions; 8→, 3↔] |
| rand0007 | FAIL | P(V7=v7 ∣ do(V1=v1) ∣ V2=v2 ∧ V5=v5 ∣ do(V3=v3)) [interventions; 11→, 2↔] |
| rand0008 | FAIL | P(V7=v7 ∣ do(V1=v1) ∣ V2=v2 ∧ V4=v4 ∣ do(V2=v2)) [interventions; 13→, 1↔] |
| rand0009 | FAIL | P(V8=v8 ∣ do(V1=v1) ∣ V5=v5 ∧ V6=v6) [interventions; 11→, 1↔] |
| rand0010 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V4=v4 ∣ do(V2=v2) ∧ V5=v5 ∣ do(V4=v4)) [interventions; 10→, 2↔] |
| rand0011 | FAIL | P(V7=v7 ∣ do(V1=v1) ∣ V6=v6 ∣ do(V3=v3) ∧ V2=v2) [interventions; 8→, 2↔] |
| rand0012 | FAIL | P(V8=v8 ∣ do(V1=v1) ∣ V6=v6 ∧ V5=v5) [interventions; 16→, 0↔] |
| rand0013 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V3=v3 ∧ V5=v5 ∣ do(V4=v4)) [interventions; 8→, 3↔] |
| rand0014 | ID | P(V5=v5 ∣ do(V1=v1) ∣ V3=v3 ∧ V4=v4) [interventions; 6→, 0↔] |
| rand0015 | FAIL | P(V7=v7 ∣ do(V1=v1) ∣ V3=v3 ∧ V6=v6 ∣ do(V2=v2)) [interventions; 9→, 2↔] |
| rand0016 | ID | P(V4=v4 ∣ do(V1=v1) ∣ V6=v6 ∣ do(V3=v3) ∧ V2=v2) [interventions; 8→, 0↔] |
| rand0017 | ID | P(V4=v4 ∣ do(V1=v1) ∣ V3=v3 ∧ V2=v2) [interventions; 5→, 1↔] |
| rand0018 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V3=v3 ∣ do(V2=v2) ∧ V4=v4) [interventions; 8→, 1↔] |
| rand0019 | FAIL | P(V7=v7 ∣ do(V1=v1) ∣ V2=v2 ∧ V5=v5) [interventions; 8→, 4↔] |
| rand0020 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V2=v2 ∧ V3=v3) [interventions; 4→, 2↔] |
| rand0021 | ID | P(V8=v8 ∣ do(V1=v1) ∣ V2=v2 ∧ V6=v6 ∣ do(V4=v4)) [interventions; 16→, 0↔] |
| rand0022 | ID | P(V7=v7 ∣ do(V1=v1) ∣ V2=v2 ∧ V3=v3) [interventions; 13→, 3↔] |
| rand0023 | ID | P(V5=v5 ∣ do(V1=v1) ∣ V3=v3 ∣ do(V2=v2) ∧ V6=v6) [interventions; 6→, 0↔] |
| rand0024 | FAIL | P(V5=v5 ∣ do(V1=v1) ∣ V4=v4 ∧ V3=v3 ∣ do(V2=v2)) [interventions; 7→, 1↔] |
| rand0025 | FAIL | P(V5=v5 ∣ do(V1=v1) ∣ V2=v2 ∧ V7=v7 ∣ do(V6=v6)) [interventions; 9→, 2↔] |
| rand0026 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V3=v3 ∧ V2=v2) [interventions; 12→, 3↔] |
| rand0027 | FAIL | P(V7=v7 ∣ do(V1=v1) ∣ V3=v3 ∧ V6=v6) [interventions; 14→, 1↔] |
| rand0028 | FAIL | P(V5=v5 ∣ do(V1=v1) ∣ V6=v6 ∧ V4=v4 ∣ do(V2=v2)) [interventions; 8→, 1↔] |
| rand0029 | FAIL | P(V7=v7 ∣ do(V1=v1) ∣ V8=v8 ∧ V2=v2) [interventions; 12→, 3↔] |
| rand0030 | FAIL | P(V8=v8 ∣ do(V1=v1) ∣ V6=v6 ∧ V5=v5) [interventions; 17→, 0↔] |
| rand0031 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V5=v5 ∧ V2=v2) [interventions; 5→, 3↔] |
| rand0032 | ID | P(V8=v8 ∣ do(V1=v1) ∣ V5=v5 ∧ V3=v3) [interventions; 9→, 2↔] |
| rand0033 | FAIL | P(V8=v8 ∣ do(V1=v1) ∣ V5=v5 ∣ do(V3=v3) ∧ V2=v2) [interventions; 14→, 2↔] |
| rand0034 | FAIL | P(V4=v4 ∣ do(V1=v1) ∣ V3=v3 ∧ V5=v5) [interventions; 6→, 0↔] |
| rand0035 | FAIL | P(V7=v7 ∣ do(V1=v1) ∣ V5=v5 ∣ do(V2=v2) ∧ V3=v3) [interventions; 10→, 1↔] |
| rand0036 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V3=v3 ∧ V5=v5 ∣ do(V4=v4)) [interventions; 11→, 2↔] |
| rand0037 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V2=v2 ∧ V3=v3) [interventions; 11→, 2↔] |
| rand0038 | FAIL | P(V8=v8 ∣ do(V1=v1) ∣ V6=v6 ∧ V2=v2) [interventions; 13→, 0↔] |
| rand0039 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V3=v3 ∧ V2=v2) [interventions; 5→, 2↔] |
| rand0040 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V3=v3 ∧ V2=v2) [interventions; 9→, 3↔] |
| rand0041 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V3=v3 ∧ V2=v2) [interventions; 12→, 0↔] |
| rand0042 | FAIL | P(V5=v5 ∣ do(V1=v1) ∣ V3=v3 ∧ V4=v4) [interventions; 6→, 0↔] |
| rand0043 | FAIL | P(V8=v8 ∣ do(V1=v1) ∣ V6=v6 ∧ V7=v7) [interventions; 14→, 1↔] |
| rand0044 | FAIL | P(V7=v7 ∣ do(V1=v1) ∣ V3=v3 ∧ V2=v2) [interventions; 12→, 0↔] |
| rand0045 | ID | P(V3=v3 ∣ do(V1=v1) ∣ V2=v2 ∧ V4=v4) [interventions; 5→, 1↔] |
| rand0046 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V3=v3 ∣ do(V2=v2) ∧ V2=v2) [interventions; 7→, 0↔] |
| rand0047 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V4=v4 ∧ V5=v5 ∣ do(V4=v4)) [interventions; 10→, 0↔] |
| rand0049 | ID | P(V4=v4 ∣ do(V1=v1) ∣ V5=v5 ∧ V3=v3) [interventions; 3→, 1↔] |
| rand0050 | FAIL | P(V7=v7 ∣ do(V1=v1) ∣ V3=v3 ∣ do(V2=v2) ∧ V4=v4) [interventions; 10→, 3↔] |
| rand0051 | FAIL | P(V4=v4 ∣ do(V1=v1) ∣ V5=v5 ∧ V3=v3 ∣ do(V2=v2)) [interventions; 5→, 0↔] |
| rand0052 | FAIL | P(V8=v8 ∣ do(V1=v1) ∣ V2=v2 ∧ V7=v7 ∣ do(V3=v3)) [interventions; 12→, 2↔] |
| rand0053 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V4=v4 ∧ V3=v3) [interventions; 12→, 2↔] |
| rand0054 | FAIL | P(V8=v8 ∣ do(V1=v1) ∣ V5=v5 ∣ do(V4=v4) ∧ V3=v3 ∣ do(V2=v2)) [interventions; 14→, 3↔] |
| rand0055 | ID | P(V2=v2 ∣ do(V1=v1) ∣ V4=v4 ∧ V5=v5 ∣ do(V3=v3)) [interventions; 4→, 2↔] |
| rand0056 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V2=v2 ∧ V4=v4) [interventions; 13→, 1↔] |
| rand0057 | FAIL | P(V5=v5 ∣ do(V1=v1) ∣ V3=v3 ∧ V4=v4) [interventions; 5→, 1↔] |
| rand0058 | FAIL | P(V7=v7 ∣ do(V1=v1) ∣ V6=v6 ∧ V8=v8) [interventions; 9→, 3↔] |
| rand0059 | FAIL | P(V4=v4 ∣ do(V1=v1) ∣ V5=v5 ∧ V3=v3) [interventions; 6→, 0↔] |
| rand0060 | FAIL | P(V4=v4 ∣ do(V1=v1) ∣ V7=v7 ∣ do(V6=v6) ∧ V5=v5 ∣ do(V3=v3)) [interventions; 9→, 1↔] |
| rand0061 | FAIL | P(V7=v7 ∣ do(V1=v1) ∣ V4=v4 ∣ do(V2=v2) ∧ V3=v3) [interventions; 12→, 2↔] |
| rand0062 | FAIL | P(V8=v8 ∣ do(V2=v2) ∣ V1=v1 ∧ V6=v6) [interventions; 9→, 2↔] |
| rand0063 | FAIL | P(V3=v3 ∣ do(V1=v1) ∣ V6=v6 ∣ do(V5=v5) ∧ V5=v5) [interventions; 5→, 0↔] |
| rand0064 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V5=v5 ∧ V2=v2) [interventions; 9→, 2↔] |
| rand0065 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V3=v3 ∣ do(V2=v2) ∧ V4=v4 ∣ do(V2=v2)) [interventions; 9→, 1↔] |
| rand0066 | FAIL | P(V7=v7 ∣ do(V1=v1) ∣ V4=v4 ∧ V3=v3) [interventions; 7→, 3↔] |
| rand0067 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V5=v5 ∣ do(V4=v4) ∧ V3=v3) [interventions; 10→, 0↔] |
| rand0068 | FAIL | P(V8=v8 ∣ do(V1=v1) ∣ V4=v4 ∧ V6=v6) [interventions; 12→, 3↔] |
| rand0069 | FAIL | P(V8=v8 ∣ do(V1=v1) ∣ V6=v6 ∣ do(V5=v5) ∧ V4=v4) [interventions; 18→, 2↔] |
| rand0070 | FAIL | P(V7=v7 ∣ do(V1=v1) ∣ V6=v6 ∣ do(V5=v5) ∧ V2=v2) [interventions; 11→, 0↔] |
| rand0071 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V7=v7 ∧ V4=v4) [interventions; 10→, 1↔] |
| rand0072 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V3=v3 ∧ V5=v5) [interventions; 6→, 2↔] |
| rand0073 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V5=v5 ∧ V4=v4) [interventions; 7→, 1↔] |
| rand0074 | FAIL | P(V8=v8 ∣ do(V1=v1) ∣ V2=v2 ∧ V3=v3) [interventions; 14→, 3↔] |
| rand0075 | FAIL | P(V5=v5 ∣ do(V1=v1) ∣ V4=v4 ∧ V2=v2) [interventions; 6→, 0↔] |
| rand0076 | FAIL | P(V7=v7 ∣ do(V1=v1) ∣ V6=v6 ∣ do(V5=v5) ∧ V3=v3) [interventions; 12→, 2↔] |
| rand0077 | FAIL | P(V5=v5 ∣ do(V1=v1) ∣ V4=v4 ∣ do(V2=v2) ∧ V3=v3) [interventions; 4→, 0↔] |
| rand0078 | FAIL | P(V8=v8 ∣ do(V1=v1) ∣ V2=v2 ∧ V7=v7 ∣ do(V5=v5)) [interventions; 12→, 2↔] |
| rand0079 | FAIL | P(V5=v5 ∣ do(V1=v1) ∣ V4=v4 ∣ do(V2=v2) ∧ V3=v3) [interventions; 10→, 1↔] |
| rand0080 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V4=v4 ∧ V3=v3) [interventions; 9→, 1↔] |
| rand0081 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V3=v3 ∧ V7=v7) [interventions; 8→, 3↔] |
| rand0082 | FAIL | P(V5=v5 ∣ do(V1=v1) ∣ V2=v2 ∧ V4=v4 ∣ do(V3=v3)) [interventions; 13→, 0↔] |
| rand0083 | ID | P(V7=v7 ∣ do(V1=v1) ∣ V8=v8 ∧ V4=v4) [interventions; 12→, 1↔] |
| rand0084 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V4=v4 ∧ V2=v2) [interventions; 6→, 0↔] |
| rand0085 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V4=v4 ∧ V2=v2) [interventions; 7→, 1↔] |
| rand0086 | FAIL | P(V7=v7 ∣ do(V1=v1) ∣ V4=v4 ∣ do(V2=v2) ∧ V8=v8) [interventions; 13→, 1↔] |
| rand0087 | FAIL | P(V7=v7 ∣ do(V1=v1) ∣ V6=v6 ∧ V2=v2) [interventions; 11→, 0↔] |
| rand0088 | FAIL | P(V8=v8 ∣ do(V1=v1) ∣ V5=v5 ∧ V6=v6 ∣ do(V5=v5)) [interventions; 13→, 1↔] |
| rand0089 | FAIL | P(V7=v7 ∣ do(V1=v1) ∣ V3=v3 ∧ V6=v6 ∣ do(V3=v3)) [interventions; 12→, 3↔] |
| rand0090 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V5=v5 ∣ do(V4=v4) ∧ V4=v4) [interventions; 11→, 0↔] |
| rand0091 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V2=v2 ∧ V7=v7 ∣ do(V2=v2)) [interventions; 16→, 2↔] |
| rand0092 | FAIL | P(V4=v4 ∣ do(V1=v1) ∣ V5=v5 ∣ do(V2=v2) ∧ V2=v2) [interventions; 6→, 0↔] |
| rand0093 | FAIL | P(V8=v8 ∣ do(V1=v1) ∣ V7=v7 ∧ V4=v4) [interventions; 12→, 2↔] |
| rand0094 | ID | P(V5=v5 ∣ do(V1=v1) ∣ V7=v7 ∣ do(V6=v6) ∧ V3=v3) [interventions; 11→, 0↔] |
| rand0095 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V4=v4 ∧ V3=v3 ∣ do(V2=v2)) [interventions; 8→, 1↔] |
| rand0096 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V3=v3 ∣ do(V2=v2) ∧ V2=v2) [interventions; 10→, 2↔] |
| rand0097 | FAIL | P(V7=v7 ∣ do(V1=v1) ∣ V4=v4 ∣ do(V3=v3) ∧ V5=v5) [interventions; 12→, 1↔] |
| rand0098 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V5=v5 ∣ do(V2=v2) ∧ V7=v7) [interventions; 11→, 0↔] |
| rand0099 | FAIL | P(V5=v5 ∣ do(V1=v1) ∣ V4=v4 ∣ do(V3=v3) ∧ V2=v2) [interventions; 7→, 0↔] |
| rand0100 | FAIL | P(V5=v5 ∣ do(V1=v1) ∣ V4=v4 ∧ V2=v2) [interventions; 9→, 1↔] |
| rand0101 | FAIL | P(V8=v8 ∣ do(V1=v1) ∣ V6=v6 ∧ V3=v3) [interventions; 14→, 1↔] |
| rand0102 | FAIL | P(V7=v7 ∣ do(V1=v1) ∣ V2=v2 ∧ V6=v6) [interventions; 13→, 0↔] |
| rand0103 | FAIL | P(V7=v7 ∣ do(V1=v1) ∣ V3=v3 ∧ V4=v4) [interventions; 12→, 2↔] |
| rand0104 | FAIL | P(V8=v8 ∣ do(V1=v1) ∣ V5=v5 ∣ do(V4=v4) ∧ V2=v2) [interventions; 13→, 2↔] |
| rand0105 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V5=v5 ∣ do(V3=v3) ∧ V4=v4) [interventions; 8→, 1↔] |
| rand0106 | FAIL | P(V5=v5 ∣ do(V1=v1) ∣ V4=v4 ∣ do(V3=v3) ∧ V3=v3) [interventions; 5→, 1↔] |
| rand0107 | ID | P(V7=v7 ∣ do(V1=v1) ∣ V6=v6 ∣ do(V5=v5) ∧ V2=v2) [interventions; 10→, 1↔] |
| rand0108 | ID | P(V2=v2 ∣ do(V1=v1) ∣ V5=v5 ∣ do(V4=v4) ∧ V6=v6) [interventions; 4→, 1↔] |
| rand0109 | FAIL | P(V8=v8 ∣ do(V1=v1) ∣ V6=v6 ∣ do(V4=v4) ∧ V3=v3) [interventions; 16→, 1↔] |
| rand0110 | FAIL | P(V4=v4 ∣ do(V1=v1) ∣ V5=v5 ∧ V3=v3) [interventions; 5→, 1↔] |
| rand0111 | FAIL | P(V5=v5 ∣ do(V1=v1) ∣ V3=v3 ∧ V4=v4) [interventions; 4→, 2↔] |
| rand0112 | FAIL | P(V5=v5 ∣ do(V1=v1) ∣ V3=v3 ∧ V2=v2) [interventions; 8→, 0↔] |
| rand0113 | FAIL | P(V7=v7 ∣ do(V1=v1) ∣ V6=v6 ∧ V2=v2) [interventions; 7→, 1↔] |
| rand0114 | FAIL | P(V7=v7 ∣ do(V1=v1) ∣ V6=v6 ∣ do(V2=v2) ∧ V2=v2) [interventions; 11→, 0↔] |
| rand0115 | FAIL | P(V4=v4 ∣ do(V1=v1) ∣ V5=v5 ∧ V2=v2) [interventions; 5→, 0↔] |
| rand0116 | FAIL | P(V8=v8 ∣ do(V1=v1) ∣ V5=v5 ∧ V7=v7) [interventions; 14→, 0↔] |
| rand0117 | FAIL | P(V8=v8 ∣ do(V1=v1) ∣ V6=v6 ∧ V2=v2) [interventions; 16→, 1↔] |
| rand0118 | FAIL | P(V7=v7 ∣ do(V1=v1) ∣ V5=v5 ∣ do(V3=v3) ∧ V6=v6 ∣ do(V4=v4)) [interventions; 11→, 0↔] |
| rand0119 | ID | P(V5=v5 ∣ do(V1=v1) ∣ V3=v3 ∧ V2=v2) [interventions; 3→, 2↔] |
| rand0120 | FAIL | P(V7=v7 ∣ do(V1=v1) ∣ V2=v2 ∧ V4=v4) [interventions; 10→, 3↔] |
| rand0121 | ID | P(V3=v3 ∣ do(V1=v1) ∣ V2=v2 ∧ V4=v4 ∣ do(V2=v2)) [interventions; 6→, 1↔] |
| rand0122 | FAIL | P(V5=v5 ∣ do(V1=v1) ∣ V2=v2 ∧ V4=v4) [interventions; 4→, 2↔] |
| rand0123 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V4=v4 ∣ do(V2=v2) ∧ V7=v7) [interventions; 12→, 0↔] |
| rand0124 | ID | P(V7=v7 ∣ do(V1=v1) ∣ V4=v4 ∧ V5=v5 ∣ do(V3=v3)) [interventions; 8→, 1↔] |
| rand0125 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V5=v5 ∣ do(V4=v4) ∧ V3=v3) [interventions; 4→, 1↔] |
| rand0126 | FAIL | P(V8=v8 ∣ do(V1=v1) ∣ V4=v4 ∧ V5=v5 ∣ do(V2=v2)) [interventions; 17→, 1↔] |
| rand0127 | FAIL | P(V4=v4 ∣ do(V1=v1) ∣ V3=v3 ∧ V2=v2) [interventions; 5→, 0↔] |
| rand0128 | ID | P(V3=v3 ∣ do(V1=v1) ∣ V2=v2 ∧ V4=v4) [interventions; 5→, 0↔] |
| rand0129 | FAIL | P(V5=v5 ∣ do(V1=v1) ∣ V4=v4 ∣ do(V3=v3) ∧ V2=v2) [interventions; 7→, 0↔] |
| rand0130 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V5=v5 ∧ V4=v4 ∣ do(V2=v2)) [interventions; 10→, 3↔] |
| rand0131 | FAIL | P(V8=v8 ∣ do(V1=v1) ∣ V2=v2 ∧ V6=v6) [interventions; 16→, 0↔] |
| rand0132 | FAIL | P(V4=v4 ∣ do(V1=v1) ∣ V7=v7 ∣ do(V2=v2) ∧ V5=v5) [interventions; 8→, 6↔] |
| rand0133 | FAIL | P(V7=v7 ∣ do(V1=v1) ∣ V6=v6 ∧ V5=v5) [interventions; 8→, 1↔] |
| rand0134 | FAIL | P(V7=v7 ∣ do(V1=v1) ∣ V3=v3 ∧ V2=v2) [interventions; 11→, 0↔] |
| rand0135 | ID | P(V4=v4 ∣ do(V1=v1) ∣ V3=v3 ∧ V5=v5 ∣ do(V3=v3)) [interventions; 6→, 0↔] |
| rand0136 | FAIL | P(V5=v5 ∣ do(V1=v1) ∣ V6=v6 ∣ do(V3=v3) ∧ V7=v7 ∣ do(V2=v2)) [interventions; 11→, 0↔] |
| rand0137 | FAIL | P(V4=v4 ∣ do(V1=v1) ∣ V3=v3 ∧ V7=v7 ∣ do(V6=v6)) [interventions; 11→, 0↔] |
| rand0138 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V4=v4 ∧ V2=v2) [interventions; 11→, 0↔] |
| rand0139 | FAIL | P(V7=v7 ∣ do(V1=v1) ∣ V4=v4 ∣ do(V2=v2) ∧ V5=v5) [interventions; 10→, 0↔] |
| rand0140 | FAIL | P(V5=v5 ∣ do(V1=v1) ∣ V3=v3 ∣ do(V2=v2) ∧ V4=v4) [interventions; 7→, 1↔] |
| rand0141 | FAIL | P(V8=v8 ∣ do(V1=v1) ∣ V5=v5 ∧ V4=v4) [interventions; 9→, 5↔] |
| rand0142 | FAIL | P(V7=v7 ∣ do(V1=v1) ∣ V5=v5 ∣ do(V2=v2) ∧ V3=v3) [interventions; 10→, 2↔] |
| rand0143 | FAIL | P(V7=v7 ∣ do(V1=v1) ∣ V3=v3 ∧ V6=v6) [interventions; 9→, 1↔] |
| rand0144 | FAIL | P(V8=v8 ∣ do(V1=v1) ∣ V7=v7 ∧ V4=v4 ∣ do(V3=v3)) [interventions; 10→, 4↔] |
| rand0145 | FAIL | P(V8=v8 ∣ do(V1=v1) ∣ V2=v2 ∧ V7=v7 ∣ do(V6=v6)) [interventions; 15→, 2↔] |
| rand0146 | ID | P(V6=v6 ∣ do(V1=v1) ∣ V3=v3 ∧ V7=v7 ∣ do(V3=v3)) [interventions; 10→, 1↔] |
| rand0147 | FAIL | P(V8=v8 ∣ do(V1=v1) ∣ V3=v3 ∧ V5=v5 ∣ do(V3=v3)) [interventions; 12→, 0↔] |
| rand0148 | FAIL | P(V5=v5 ∣ do(V1=v1) ∣ V4=v4 ∧ V6=v6) [interventions; 6→, 2↔] |
| rand0149 | ID | P(V5=v5 ∣ do(V1=v1) ∣ V6=v6 ∧ V3=v3) [interventions; 7→, 0↔] |
| rand0150 | FAIL | P(V5=v5 ∣ do(V1=v1) ∣ V2=v2 ∧ V4=v4) [interventions; 5→, 1↔] |
| rand0151 | FAIL | P(V7=v7 ∣ do(V1=v1) ∣ V6=v6 ∧ V5=v5 ∣ do(V2=v2)) [interventions; 14→, 0↔] |
| rand0152 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V2=v2 ∧ V7=v7) [interventions; 9→, 2↔] |
| rand0153 | FAIL | P(V5=v5 ∣ do(V1=v1) ∣ V3=v3 ∣ do(V2=v2) ∧ V2=v2) [interventions; 7→, 0↔] |
| rand0154 | FAIL | P(V8=v8 ∣ do(V1=v1) ∣ V6=v6 ∣ do(V2=v2) ∧ V5=v5) [interventions; 16→, 1↔] |
| rand0155 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V4=v4 ∣ do(V2=v2) ∧ V5=v5) [interventions; 6→, 1↔] |
| rand0156 | ID | P(V5=v5 ∣ do(V1=v1) ∣ V2=v2 ∧ V4=v4 ∣ do(V3=v3)) [interventions; 5→, 0↔] |
| rand0157 | FAIL | P(V8=v8 ∣ do(V1=v1) ∣ V4=v4 ∧ V7=v7) [interventions; 15→, 0↔] |
| rand0158 | FAIL | P(V4=v4 ∣ do(V1=v1) ∣ V2=v2 ∧ V5=v5) [interventions; 5→, 0↔] |
| rand0159 | FAIL | P(V8=v8 ∣ do(V1=v1) ∣ V5=v5 ∧ V4=v4) [interventions; 18→, 1↔] |
| rand0160 | FAIL | P(V8=v8 ∣ do(V1=v1) ∣ V3=v3 ∧ V5=v5) [interventions; 15→, 1↔] |
| rand0161 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V3=v3 ∧ V2=v2) [interventions; 12→, 1↔] |
| rand0162 | FAIL | P(V8=v8 ∣ do(V1=v1) ∣ V2=v2 ∧ V6=v6) [interventions; 16→, 2↔] |
| rand0163 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V4=v4 ∧ V3=v3) [interventions; 13→, 2↔] |
| rand0164 | FAIL | P(V8=v8 ∣ do(V1=v1) ∣ V2=v2 ∧ V6=v6 ∣ do(V5=v5)) [interventions; 13→, 1↔] |
| rand0165 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V2=v2 ∧ V4=v4 ∣ do(V3=v3)) [interventions; 8→, 0↔] |
| rand0166 | FAIL | P(V7=v7 ∣ do(V1=v1) ∣ V5=v5 ∧ V4=v4 ∣ do(V2=v2)) [interventions; 12→, 1↔] |
| rand0167 | FAIL | P(V8=v8 ∣ do(V1=v1) ∣ V6=v6 ∧ V2=v2) [interventions; 12→, 1↔] |
| rand0168 | FAIL | P(V5=v5 ∣ do(V1=v1) ∣ V4=v4 ∧ V2=v2) [interventions; 9→, 0↔] |
| rand0169 | FAIL | P(V7=v7 ∣ do(V1=v1) ∣ V4=v4 ∣ do(V3=v3) ∧ V2=v2) [interventions; 15→, 2↔] |
| rand0170 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V3=v3 ∧ V4=v4 ∣ do(V2=v2)) [interventions; 10→, 0↔] |
| rand0171 | FAIL | P(V5=v5 ∣ do(V1=v1) ∣ V3=v3 ∧ V7=v7) [interventions; 11→, 2↔] |
| rand0172 | FAIL | P(V4=v4 ∣ do(V1=v1) ∣ V3=v3 ∣ do(V2=v2) ∧ V2=v2) [interventions; 5→, 0↔] |
| rand0173 | FAIL | P(V5=v5 ∣ do(V1=v1) ∣ V4=v4 ∧ V2=v2) [interventions; 5→, 0↔] |
| rand0174 | FAIL | P(V7=v7 ∣ do(V1=v1) ∣ V4=v4 ∧ V2=v2) [interventions; 13→, 0↔] |
| rand0175 | FAIL | P(V8=v8 ∣ do(V1=v1) ∣ V5=v5 ∧ V3=v3) [interventions; 11→, 1↔] |
| rand0176 | ID | P(V3=v3 ∣ do(V1=v1) ∣ V5=v5 ∧ V4=v4) [interventions; 7→, 0↔] |
| rand0177 | FAIL | P(V7=v7 ∣ do(V1=v1) ∣ V2=v2 ∧ V6=v6) [interventions; 9→, 2↔] |
| rand0178 | FAIL | P(V7=v7 ∣ do(V1=v1) ∣ V6=v6 ∧ V5=v5) [interventions; 11→, 0↔] |
| rand0179 | FAIL | P(V8=v8 ∣ do(V1=v1) ∣ V2=v2 ∧ V4=v4 ∣ do(V3=v3)) [interventions; 14→, 1↔] |
| rand0180 | FAIL | P(V3=v3 ∣ do(V1=v1) ∣ V4=v4 ∣ do(V2=v2) ∧ V2=v2) [interventions; 5→, 0↔] |
| rand0181 | FAIL | P(V5=v5 ∣ do(V1=v1) ∣ V4=v4 ∧ V3=v3) [interventions; 6→, 0↔] |
| rand0182 | FAIL | P(V5=v5 ∣ do(V1=v1) ∣ V3=v3 ∣ do(V2=v2) ∧ V2=v2) [interventions; 5→, 2↔] |
| rand0183 | ID | P(V3=v3 ∣ do(V1=v1) ∣ V4=v4 ∧ V7=v7) [interventions; 10→, 1↔] |
| rand0184 | ID | P(V5=v5 ∣ do(V1=v1) ∣ V6=v6 ∧ V4=v4 ∣ do(V3=v3)) [interventions; 8→, 0↔] |
| rand0185 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V4=v4 ∧ V3=v3 ∣ do(V2=v2)) [interventions; 6→, 2↔] |
| rand0186 | FAIL | P(V8=v8 ∣ do(V1=v1) ∣ V3=v3 ∣ do(V2=v2) ∧ V4=v4) [interventions; 14→, 2↔] |
| rand0187 | FAIL | P(V5=v5 ∣ do(V1=v1) ∣ V4=v4 ∧ V3=v3) [interventions; 6→, 0↔] |
| rand0188 | FAIL | P(V8=v8 ∣ do(V1=v1) ∣ V7=v7 ∣ do(V2=v2) ∧ V3=v3 ∣ do(V2=v2)) [interventions; 13→, 3↔] |
| rand0189 | FAIL | P(V5=v5 ∣ do(V1=v1) ∣ V3=v3 ∧ V6=v6 ∣ do(V3=v3)) [interventions; 7→, 1↔] |
| rand0190 | FAIL | P(V8=v8 ∣ do(V1=v1) ∣ V4=v4 ∧ V3=v3) [interventions; 14→, 1↔] |
| rand0191 | FAIL | P(V5=v5 ∣ do(V1=v1) ∣ V3=v3 ∧ V4=v4 ∣ do(V3=v3)) [interventions; 5→, 1↔] |
| rand0192 | FAIL | P(V5=v5 ∣ do(V1=v1) ∣ V7=v7 ∧ V2=v2) [interventions; 17→, 1↔] |
| rand0193 | FAIL | P(V8=v8 ∣ do(V1=v1) ∣ V5=v5 ∣ do(V2=v2) ∧ V4=v4) [interventions; 15→, 1↔] |
| rand0194 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V4=v4 ∧ V2=v2) [interventions; 9→, 0↔] |
| rand0195 | ID | P(V2=v2 ∣ do(V1=v1) ∣ V5=v5 ∣ do(V4=v4) ∧ V3=v3) [interventions; 8→, 2↔] |
| rand0196 | FAIL | P(V8=v8 ∣ do(V1=v1) ∣ V6=v6 ∣ do(V4=v4) ∧ V2=v2) [interventions; 12→, 3↔] |
| rand0197 | FAIL | P(V5=v5 ∣ do(V1=v1) ∣ V3=v3 ∣ do(V2=v2) ∧ V4=v4 ∣ do(V2=v2)) [interventions; 4→, 1↔] |
| rand0198 | ID | P(V3=v3 ∣ do(V1=v1) ∣ V5=v5 ∣ do(V4=v4) ∧ V4=v4 ∣ do(V2=v2)) [interventions; 4→, 1↔] |
| rand0199 | FAIL | P(V7=v7 ∣ do(V1=v1) ∣ V2=v2 ∧ V3=v3 ∣ do(V2=v2)) [interventions; 11→, 2↔] |
| rand0200 | FAIL | P(V7=v7 ∣ do(V1=v1) ∣ V2=v2 ∧ V6=v6) [interventions; 14→, 0↔] |
| rand0201 | ID | P(V8=v8 ∣ do(V1=v1) ∣ V7=v7 ∣ do(V4=v4) ∧ V2=v2) [interventions; 12→, 1↔] |
| rand0202 | ID | P(V3=v3 ∣ do(V1=v1) ∣ V2=v2 ∧ V4=v4) [interventions; 5→, 1↔] |
| rand0203 | FAIL | P(V5=v5 ∣ do(V1=v1) ∣ V2=v2 ∧ V4=v4) [interventions; 7→, 1↔] |
| rand0204 | ID | P(V4=v4 ∣ do(V1=v1) ∣ V3=v3 ∣ do(V2=v2) ∧ V5=v5) [interventions; 5→, 0↔] |
| rand0205 | FAIL | P(V8=v8 ∣ do(V1=v1) ∣ V5=v5 ∣ do(V3=v3) ∧ V3=v3 ∣ do(V2=v2)) [interventions; 14→, 5↔] |
| rand0206 | FAIL | P(V8=v8 ∣ do(V1=v1) ∣ V2=v2 ∧ V6=v6) [interventions; 13→, 1↔] |
| rand0207 | FAIL | P(V8=v8 ∣ do(V1=v1) ∣ V6=v6 ∣ do(V3=v3) ∧ V2=v2) [interventions; 12→, 3↔] |
| rand0208 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V8=v8 ∣ do(V3=v3) ∧ V4=v4 ∣ do(V2=v2)) [interventions; 14→, 1↔] |
| rand0209 | ID | P(V3=v3 ∣ do(V1=v1) ∣ V5=v5 ∣ do(V4=v4) ∧ V4=v4) [interventions; 5→, 0↔] |
| rand0210 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V2=v2 ∧ V3=v3) [interventions; 8→, 2↔] |
| rand0211 | FAIL | P(V7=v7 ∣ do(V1=v1) ∣ V3=v3 ∧ V5=v5) [interventions; 11→, 1↔] |
| rand0212 | FAIL | P(V5=v5 ∣ do(V1=v1) ∣ V2=v2 ∧ V3=v3) [interventions; 6→, 0↔] |
| rand0213 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V4=v4 ∧ V2=v2) [interventions; 8→, 0↔] |
| rand0214 | FAIL | P(V5=v5 ∣ do(V1=v1) ∣ V2=v2 ∧ V4=v4) [interventions; 4→, 2↔] |
| rand0215 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V4=v4 ∣ do(V2=v2) ∧ V5=v5) [interventions; 8→, 0↔] |
| rand0216 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V4=v4 ∣ do(V2=v2) ∧ V5=v5) [interventions; 11→, 0↔] |
| rand0217 | FAIL | P(V5=v5 ∣ do(V1=v1) ∣ V3=v3 ∧ V4=v4) [interventions; 6→, 1↔] |
| rand0218 | FAIL | P(V5=v5 ∣ do(V1=v1) ∣ V6=v6 ∧ V2=v2) [interventions; 5→, 3↔] |
| rand0219 | FAIL | P(V8=v8 ∣ do(V1=v1) ∣ V2=v2 ∧ V7=v7 ∣ do(V3=v3)) [interventions; 12→, 1↔] |
| rand0220 | FAIL | P(V8=v8 ∣ do(V2=v2) ∣ V7=v7 ∧ V4=v4 ∣ do(V3=v3)) [interventions; 14→, 2↔] |
| rand0221 | FAIL | P(V4=v4 ∣ do(V1=v1) ∣ V6=v6 ∧ V2=v2) [interventions; 10→, 2↔] |
| rand0222 | FAIL | P(V5=v5 ∣ do(V1=v1) ∣ V3=v3 ∧ V2=v2) [interventions; 5→, 0↔] |
| rand0223 | FAIL | P(V7=v7 ∣ do(V1=v1) ∣ V3=v3 ∧ V5=v5) [interventions; 9→, 1↔] |
| rand0224 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V2=v2 ∧ V4=v4) [interventions; 8→, 3↔] |
| rand0225 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V2=v2 ∧ V5=v5 ∣ do(V4=v4)) [interventions; 10→, 2↔] |
| rand0226 | FAIL | P(V8=v8 ∣ do(V1=v1) ∣ V6=v6 ∧ V5=v5) [interventions; 10→, 0↔] |
| rand0227 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V5=v5 ∣ do(V3=v3) ∧ V2=v2) [interventions; 6→, 1↔] |
| rand0228 | FAIL | P(V6=v6 ∣ do(V2=v2) ∣ V1=v1 ∧ V3=v3) [interventions; 5→, 2↔] |
| rand0229 | FAIL | P(V5=v5 ∣ do(V1=v1) ∣ V4=v4 ∧ V3=v3 ∣ do(V2=v2)) [interventions; 6→, 1↔] |
| rand0230 | FAIL | P(V5=v5 ∣ do(V1=v1) ∣ V6=v6 ∧ V2=v2) [interventions; 7→, 0↔] |
| rand0231 | FAIL | P(V5=v5 ∣ do(V1=v1) ∣ V3=v3 ∧ V2=v2) [interventions; 8→, 0↔] |
| rand0232 | FAIL | P(V3=v3 ∣ do(V1=v1) ∣ V4=v4 ∣ do(V2=v2) ∧ V2=v2) [interventions; 8→, 2↔] |
| rand0233 | ID | P(V5=v5 ∣ do(V1=v1) ∣ V2=v2 ∧ V3=v3 ∣ do(V2=v2)) [interventions; 5→, 1↔] |
| rand0234 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V2=v2 ∧ V3=v3) [interventions; 11→, 2↔] |
| rand0235 | ID | P(V2=v2 ∣ do(V1=v1) ∣ V6=v6 ∧ V4=v4 ∣ do(V3=v3)) [interventions; 14→, 1↔] |
| rand0236 | FAIL | P(V7=v7 ∣ do(V1=v1) ∣ V5=v5 ∧ V4=v4) [interventions; 11→, 0↔] |
| rand0237 | ID | P(V7=v7 ∣ do(V1=v1) ∣ V2=v2 ∧ V6=v6 ∣ do(V4=v4)) [interventions; 6→, 0↔] |
| rand0238 | FAIL | P(V7=v7 ∣ do(V1=v1) ∣ V4=v4 ∧ V5=v5 ∣ do(V2=v2)) [interventions; 7→, 3↔] |
| rand0239 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V5=v5 ∣ do(V2=v2) ∧ V3=v3) [interventions; 6→, 1↔] |
| rand0240 | FAIL | P(V7=v7 ∣ do(V1=v1) ∣ V3=v3 ∧ V5=v5) [interventions; 12→, 0↔] |
| rand0241 | FAIL | P(V8=v8 ∣ do(V1=v1) ∣ V5=v5 ∧ V2=v2) [interventions; 7→, 2↔] |
| rand0242 | FAIL | P(V8=v8 ∣ do(V1=v1) ∣ V7=v7 ∧ V2=v2) [interventions; 15→, 0↔] |
| rand0243 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V2=v2 ∧ V3=v3) [interventions; 10→, 1↔] |
| rand0244 | FAIL | P(V4=v4 ∣ do(V1=v1) ∣ V5=v5 ∧ V6=v6) [interventions; 9→, 0↔] |
| rand0245 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V4=v4 ∣ do(V3=v3) ∧ V2=v2) [interventions; 6→, 0↔] |
| rand0246 | ID | P(V3=v3 ∣ do(V1=v1) ∣ V4=v4 ∧ V2=v2) [interventions; 4→, 1↔] |
| rand0247 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V4=v4 ∧ V7=v7) [interventions; 6→, 2↔] |
| rand0248 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V4=v4 ∧ V3=v3) [interventions; 4→, 0↔] |
| rand0249 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V2=v2 ∧ V5=v5) [interventions; 8→, 1↔] |
| rand0250 | FAIL | P(V5=v5 ∣ do(V1=v1) ∣ V4=v4 ∧ V3=v3) [interventions; 4→, 3↔] |
| rand0251 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V5=v5 ∣ do(V3=v3) ∧ V4=v4 ∣ do(V3=v3)) [interventions; 11→, 0↔] |
| rand0252 | ID | P(V2=v2 ∣ do(V1=v1) ∣ V6=v6 ∧ V5=v5) [interventions; 8→, 1↔] |
| rand0253 | ID | P(V4=v4 ∣ do(V1=v1) ∣ V3=v3 ∧ V2=v2) [interventions; 4→, 0↔] |
| rand0254 | FAIL | P(V4=v4 ∣ do(V1=v1) ∣ V5=v5 ∧ V3=v3) [interventions; 6→, 2↔] |
| rand0256 | FAIL | P(V5=v5 ∣ do(V1=v1) ∣ V3=v3 ∧ V4=v4) [interventions; 6→, 0↔] |
| rand0257 | ID | P(V8=v8 ∣ do(V1=v1) ∣ V5=v5 ∣ do(V3=v3) ∧ V7=v7 ∣ do(V4=v4)) [interventions; 10→, 2↔] |
| rand0258 | FAIL | P(V5=v5 ∣ do(V1=v1) ∣ V4=v4 ∧ V3=v3) [interventions; 5→, 1↔] |
| rand0259 | FAIL | P(V7=v7 ∣ do(V1=v1) ∣ V2=v2 ∧ V8=v8) [interventions; 12→, 1↔] |
| rand0260 | FAIL | P(V5=v5 ∣ do(V1=v1) ∣ V6=v6 ∣ do(V3=v3) ∧ V4=v4) [interventions; 6→, 0↔] |
| rand0261 | FAIL | P(V5=v5 ∣ do(V1=v1) ∣ V6=v6 ∧ V4=v4) [interventions; 5→, 0↔] |
| rand0262 | ID | P(V6=v6 ∣ do(V1=v1) ∣ V3=v3 ∧ V4=v4) [interventions; 9→, 0↔] |
| rand0263 | FAIL | P(V6=v6 ∣ do(V2=v2) ∣ V7=v7 ∣ do(V3=v3) ∧ V3=v3) [interventions; 8→, 1↔] |
| rand0264 | ID | P(V5=v5 ∣ do(V1=v1) ∣ V6=v6 ∣ do(V2=v2) ∧ V4=v4) [interventions; 11→, 0↔] |
| rand0265 | FAIL | P(V8=v8 ∣ do(V1=v1) ∣ V5=v5 ∣ do(V4=v4) ∧ V4=v4) [interventions; 15→, 1↔] |
| rand0266 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V3=v3 ∧ V5=v5) [interventions; 8→, 2↔] |
| rand0267 | FAIL | P(V8=v8 ∣ do(V1=v1) ∣ V4=v4 ∧ V7=v7) [interventions; 15→, 0↔] |
| rand0268 | FAIL | P(V7=v7 ∣ do(V1=v1) ∣ V5=v5 ∧ V4=v4) [interventions; 12→, 0↔] |
| rand0269 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V2=v2 ∧ V5=v5) [interventions; 10→, 1↔] |
| rand0270 | FAIL | P(V8=v8 ∣ do(V1=v1) ∣ V6=v6 ∧ V3=v3) [interventions; 11→, 1↔] |
| rand0271 | FAIL | P(V8=v8 ∣ do(V1=v1) ∣ V7=v7 ∣ do(V3=v3) ∧ V3=v3) [interventions; 13→, 3↔] |
| rand0272 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V3=v3 ∧ V5=v5) [interventions; 7→, 1↔] |
| rand0273 | ID | P(V8=v8 ∣ do(V1=v1) ∣ V5=v5 ∧ V7=v7) [interventions; 12→, 1↔] |
| rand0274 | FAIL | P(V7=v7 ∣ do(V1=v1) ∣ V3=v3 ∣ do(V2=v2) ∧ V5=v5) [interventions; 12→, 2↔] |
| rand0275 | FAIL | P(V8=v8 ∣ do(V1=v1) ∣ V5=v5 ∧ V6=v6 ∣ do(V3=v3)) [interventions; 13→, 3↔] |
| rand0276 | FAIL | P(V5=v5 ∣ do(V1=v1) ∣ V4=v4 ∧ V3=v3 ∣ do(V2=v2)) [interventions; 5→, 0↔] |
| rand0277 | ID | P(V4=v4 ∣ do(V1=v1) ∣ V5=v5 ∣ do(V3=v3) ∧ V3=v3) [interventions; 4→, 2↔] |
| rand0278 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V2=v2 ∧ V5=v5) [interventions; 10→, 1↔] |
| rand0279 | FAIL | P(V5=v5 ∣ do(V1=v1) ∣ V2=v2 ∧ V4=v4) [interventions; 6→, 2↔] |
| rand0280 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V5=v5 ∧ V3=v3) [interventions; 6→, 1↔] |
| rand0281 | FAIL | P(V8=v8 ∣ do(V1=v1) ∣ V6=v6 ∧ V3=v3) [interventions; 16→, 0↔] |
| rand0282 | FAIL | P(V8=v8 ∣ do(V1=v1) ∣ V2=v2 ∧ V7=v7) [interventions; 12→, 3↔] |
| rand0283 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V5=v5 ∣ do(V4=v4) ∧ V3=v3) [interventions; 11→, 3↔] |
| rand0284 | FAIL | P(V5=v5 ∣ do(V2=v2) ∣ V4=v4 ∧ V1=v1) [interventions; 5→, 3↔] |
| rand0285 | FAIL | P(V8=v8 ∣ do(V1=v1) ∣ V2=v2 ∧ V4=v4) [interventions; 14→, 2↔] |
| rand0286 | FAIL | P(V7=v7 ∣ do(V1=v1) ∣ V4=v4 ∧ V8=v8) [interventions; 13→, 0↔] |
| rand0287 | ID | P(V7=v7 ∣ do(V1=v1) ∣ V6=v6 ∣ do(V2=v2) ∧ V8=v8 ∣ do(V3=v3)) [interventions; 12→, 1↔] |
| rand0288 | FAIL | P(V4=v4 ∣ do(V1=v1) ∣ V3=v3 ∧ V2=v2) [interventions; 5→, 0↔] |
| rand0289 | FAIL | P(V6=v6 ∣ do(V1=v1) ∣ V2=v2 ∧ V5=v5) [interventions; 9→, 0↔] |
| rand0290 | ID | P(V3=v3 ∣ do(V1=v1) ∣ V2=v2 ∧ V5=v5) [interventions; 5→, 0↔] |
| rand0291 | FAIL | P(V8=v8 ∣ do(V1=v1) ∣ V7=v7 ∧ V4=v4) [interventions; 12→, 1↔] |
| rand0292 | FAIL | P(V4=v4 ∣ do(V1=v1) ∣ V5=v5 ∧ V3=v3) [interventions; 6→, 0↔] |
| rand0293 | FAIL | P(V7=v7 ∣ do(V1=v1) ∣ V4=v4 ∧ V2=v2) [interventions; 12→, 1↔] |
| rand0294 | FAIL | P(V7=v7 ∣ do(V1=v1) ∣ V3=v3 ∣ do(V2=v2) ∧ V6=v6) [interventions; 8→, 2↔] |
| rand0295 | ID | P(V4=v4 ∣ do(V1=v1) ∣ V6=v6 ∧ V2=v2) [interventions; 8→, 0↔] |
| rand0296 | ID | P(V3=v3 ∣ do(V1=v1) ∣ V5=v5 ∧ V2=v2) [interventions; 4→, 1↔] |
| rand0297 | FAIL | P(V7=v7 ∣ do(V1=v1) ∣ V2=v2 ∧ V3=v3) [interventions; 15→, 3↔] |
| rand0298 | FAIL | P(V7=v7 ∣ do(V1=v1) ∣ V5=v5 ∧ V6=v6 ∣ do(V2=v2)) [interventions; 10→, 0↔] |
| rand0299 | FAIL | P(V7=v7 ∣ do(V1=v1) ∣ V3=v3 ∧ V4=v4) [interventions; 10→, 0↔] |
| rand0300 | FAIL | P(V7=v7 ∣ do(V1=v1) ∣ V5=v5 ∧ V3=v3) [interventions; 13→, 2↔] |

