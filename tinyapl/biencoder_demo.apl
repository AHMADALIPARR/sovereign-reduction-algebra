⍝ Runnable demo. Seeded LCG, fixed permutation weights, SUBLEQ route.
⍝ Prints flat row-major tensors. Python scripts/run_biencoder.py parses this.
⎕←"BIENCODER_V1"
seed←20261002
radix←5
m←4
k←4
n←4
⎕←"M"
⎕←⍕m
⎕←"K"
⎕←⍕k
⎕←"N"
⎕←⍕n
⎕←"SEED"
⎕←⍕seed
ab←(m×k)LcgDraw⟨seed⋄radix⟩
av←⊃0⊇ab
seed2←1⊇ab
bb←(k×n)LcgDraw⟨seed2⋄radix⟩
bv←⊃0⊇bb
a←(⟨m⋄k⟩)⍴av
b←(⟨k⋄n⟩)⍴bv
wq←4‿4⍴⟨0⋄1⋄0⋄0⋄0⋄0⋄1⋄0⋄0⋄0⋄0⋄1⋄1⋄0⋄0⋄0⟩
wk←wq
qs←a+/∙×wq
ks←(⍉b)+/∙×wk
pr←qs PredictRows ks
ex←qs+/∙×⍉ks
ref←a+/∙×b
ag←qs AggRows ks
pd←qs PredFlat ks
gp←qs GSafePredict ks
err←⌈/∊|pr-ref
match←∧/∊ex=ref
⎕←"A"
⎕←⍕∊a
⎕←"B"
⎕←⍕∊b
⎕←"PREDICTED"
⎕←⍕∊pr
⎕←"EXACT_HEAD"
⎕←⍕∊ex
⎕←"REFERENCE"
⎕←⍕∊ref
⎕←"AGGREGATES"
⎕←⍕∊ag
⎕←"PREDICATES"
⎕←⍕pd
⎕←"GSAFE_PREDICTED"
⎕←⍕∊gp
⎕←"MAX_ABS_ERROR"
⎕←⍕err
⎕←"EXACT_HEAD_MATCH"
⎕←⍕match
⎕←"NOT_SOFTMAX"
⎕←1
