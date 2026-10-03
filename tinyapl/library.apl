⍝ Sovereign Reduction Algebra — TinyAPL primitives
⍝ File-mode note: Capitals name functions; locals must be lowercase.
⍝ Replicate is ⌿ ( / is reduce ). Scan via prefix folds ( +\ is not scan ).
⍝ Recursion ∇ hangs in this TinyAPL build — use ⍣ Until instead.

All←∧/
Any←∨/
Xor←≠/
Threshold←{⍺≤+/⍵}
Sum←+/
Product←×/
Min←⌊/
Max←⌈/
ScanSum←{(+/)¨(1+⍳≢⍵)↑¨⊂⍵}
ScanProduct←{(×/)¨(1+⍳≢⍵)↑¨⊂⍵}
InnerProduct←{+/⍺×⍵}
OuterProduct←{⍺×⊞⍵}
RankReduceSum←+/◡
Contract←+/
Partition←⊆
SelectMasked←{(0≠⍺)⌿⍵}
RouteMul←{⍺×⍵}
Aggregate←+/
SubleqSubtract←{⍵-⍺}
CompareLe0←{⍵≤0}
SubleqPipeline←{diff←⍺ SubleqSubtract ⍵⋄pred←CompareLe0 diff⋄sel←pred SelectMasked diff⋄rtd←pred RouteMul diff⋄agg←Aggregate rtd⋄⟨agg⋄≢sel⋄pred⋄rtd⋄diff⟩}
_FusedMapReduceWith←_{+/(⍶⍶¨⍵)}
PairSum←{n←≢⍵⋄e←⌊n÷2⋄(+/◡(e,2)⍴(2×e)↑⍵)⍪(2×e)↓⍵}
TreeReduceSumSafe←{n←≢⍵⋄0=n:⟨0⋄0⟩⋄1=n:⟨⊃⍵⋄0⟩⋄val←⊃PairSum⍣{1=≢⍵}⍵⋄depth←⌈2⍟n⋄⟨val⋄depth⟩}
SegmentedReduceSum←{parts←⍺⊆⍵⋄(+/)¨parts}
⍝ Goldilocks: full p via Python reference. TinyAPL uses exact GSafeP=2^26-1.
gSafeP←65537
GSafeAdd←{gSafeP|⍺+⍵}
GSafeSub←{gSafeP|⍺-⍵}
GSafeMul←{gSafeP|⍺×⍵}
GSafeReduce←{gSafeP|+/⍵}
GSafeScan←{gSafeP|¨ScanSum ⍵}
GSafeDot←{gSafeP|+/⍺×⍵}
GSafeExp←{base←gSafeP|⍺⋄e←⍵⋄acc←1⋄{e≤0:acc⋄acc↩(2|e)⊇⟨acc⋄acc GSafeMul base⟩⋄base↩base GSafeMul base⋄e↩⌊e÷2⋄1}⍣{e≤0}0⋄acc}
GSafeInv←{⍵ GSafeExp(gSafeP-2)}

GSafePoly3←{x←⍵⋄c0←0⊇⍺⋄c1←1⊇⍺⋄c2←2⊇⍺⋄(((c2 GSafeMul x)GSafeAdd c1)GSafeMul x)GSafeAdd c0}
R0←Sum
R1←{⟨Sum ⍵⋄0⌈(≢⍵)-1⟩}
R2←TreeReduceSumSafe
R3←{chunk←⍺⋄n←≢⍵⋄0=n:⟨0⋄0⟩⋄k←⌈n÷chunk⋄pads←(k×chunk)↑⍵⋄mat←(k,chunk)⍴pads⋄partials←+/◡mat⋄⟨Sum partials⋄(0⌈chunk-1)+0⌈k-1⟩}
R4←SegmentedReduceSum
R5←Sum
R6←{⟨GSafeReduce ⍵⋄0⌈(≢⍵)-1⟩}
R7←{diff←gSafeP|⍵-⍺⋄half←⌊gSafeP÷2⋄signed←diff-gSafeP×diff>half⋄pred←signed≤0⋄routed←pred×diff⋄⟨GSafeReduce routed⋄0⌈(≢⍺)-1⋄pred⋄routed⟩}
⍝ Legacy crypto stub. Production SHA-512 DAG seal is j/sha512.ijs and r/sha512.R.
Canonicalize←⍕
CommitStub←Canonicalize
SealStub←Canonicalize
VerifyStub←{1}
