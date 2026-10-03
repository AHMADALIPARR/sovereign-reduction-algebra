⍝ Auto-synced excerpt from library.apl — execute via demo_run.apl / pipeline flatten

⍝ Sovereign Reduction Algebra — TinyAPL primitives
⍝ File-mode note: Capitals name functions; locals must be lowercase.
⍝ Goldilocks: full p via Python reference. TinyAPL uses exact GSafeP=2^26-1.
R0←Sum
R1←{⟨Sum ⍵⋄0⌈(≢⍵)-1⟩}
R2←TreeReduceSumSafe
R3←{chunk←⍺⋄n←≢⍵⋄0=n:⟨0⋄0⟩⋄k←⌈n÷chunk⋄pads←(k×chunk)↑⍵⋄mat←(k,chunk)⍴pads⋄partials←+/◡mat⋄⟨Sum partials⋄(0⌈chunk-1)+0⌈k-1⟩}
R4←SegmentedReduceSum
R5←Sum
R6←{⟨GSafeReduce ⍵⋄0⌈(≢⍵)-1⟩}
R7←{diff←gSafeP|⍵-⍺⋄half←⌊gSafeP÷2⋄signed←diff-gSafeP×diff>half⋄pred←signed≤0⋄routed←pred×diff⋄⟨GSafeReduce routed⋄0⌈(≢⍺)-1⋄pred⋄routed⟩}
⍝ Legacy crypto stub. Production SHA-512 DAG seal is j/sha512.ijs and r/sha512.R.
