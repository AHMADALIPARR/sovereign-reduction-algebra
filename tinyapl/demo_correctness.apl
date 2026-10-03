⎕←"ALL"⋄⎕←⍕All ⟨1⋄1⋄1⟩
⎕←"ANY"⋄⎕←⍕Any ⟨0⋄0⋄1⟩
⎕←"XOR"⋄⎕←⍕Xor ⟨1⋄0⋄1⋄1⟩
⎕←"THR"⋄⎕←⍕3 Threshold ⟨1⋄1⋄1⋄0⟩
⎕←"SUM"⋄⎕←⍕Sum ⟨1⋄2⋄3⋄4⟩
⎕←"PROD"⋄⎕←⍕Product ⟨1⋄2⋄3⋄4⟩
⎕←"MIN"⋄⎕←⍕Min ⟨3⋄1⋄4⟩
⎕←"MAX"⋄⎕←⍕Max ⟨3⋄1⋄4⟩
⎕←"SCAN"⋄⎕←⍕ScanSum ⟨1⋄2⋄3⋄4⟩
⎕←"IP"⋄⎕←⍕⟨1⋄2⋄3⟩ InnerProduct ⟨4⋄5⋄6⟩
⎕←"OP"⋄⎕←⍕⟨1⋄2⟩ OuterProduct ⟨3⋄4⋄5⟩
⎕←"TREE"⋄⎕←⍕TreeReduceSumSafe ⟨1⋄2⋄3⋄4⋄5⋄6⋄7⋄8⟩
⎕←"SEG"⋄⎕←⍕⟨1⋄0⋄1⋄1⟩ SegmentedReduceSum ⟨10⋄20⋄30⋄40⟩
⎕←"SUB"⋄⎕←⍕⟨1⋄5⋄3⟩ SubleqPipeline ⟨4⋄2⋄3⟩
⎕←"R1"⋄⎕←⍕R1 ⟨1⋄2⋄3⋄4⟩
⎕←"R2"⋄⎕←⍕R2 ⟨1⋄2⋄3⋄4⋄5⋄6⋄7⋄8⟩
⎕←"R3"⋄⎕←⍕4 R3 ⟨1⋄2⋄3⋄4⋄5⋄6⋄7⋄8⟩
⎕←"R6"⋄⎕←⍕R6 ⟨1⋄2⋄3⋄4⟩
⎕←"R7"⋄⎕←⍕⟨1⋄2⋄3⟩ R7 ⟨4⋄1⋄8⟩
⎕←"GADD"⋄⎕←⍕10 GSafeAdd 20
⎕←"GMUL"⋄⎕←⍕5 GSafeMul 7
⎕←"GRED"⋄⎕←⍕GSafeReduce ⟨1⋄2⋄3⋄4⟩
⎕←"GSCAN"⋄⎕←⍕GSafeScan ⟨1⋄2⋄3⋄4⟩
⎕←"GDOT"⋄⎕←⍕⟨1⋄2⋄3⟩ GSafeDot ⟨4⋄5⋄6⟩
⎕←"FUSED"⋄⎕←⍕{⍵×⍵} _FusedMapReduceWith ⟨1⋄2⋄3⟩
⎕←"GPOLY"⋄⎕←⍕⟨1⋄2⋄3⟩ GSafePoly3 2
⎕←"GINV"⋄⎕←⍕3 GSafeMul (GSafeInv 3)
