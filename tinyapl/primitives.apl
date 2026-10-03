⍝ Auto-synced excerpt from library.apl — execute via demo_run.apl / pipeline flatten

⍝ Sovereign Reduction Algebra — TinyAPL primitives
⍝ File-mode note: Capitals name functions; locals must be lowercase.
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
⍝ Legacy crypto stub. Production SHA-512 DAG seal is j/sha512.ijs and r/sha512.R.
