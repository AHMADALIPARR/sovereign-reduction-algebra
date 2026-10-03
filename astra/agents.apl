⍝ Astra APL: agent registry and numerical specialist implementations.
⍝ An agent receives a nested request: numeric-data prior-proposals round.
⍝ A proposal is a numeric vector; specialists may implement any APL function
⍝ with this calling convention. These built-ins compute real estimators.

∇ ResetAgents
 AgentProfiles←⍬
 AgentFunctions←⍬
∇

∇ Z←Register X;P;F;I
 ⍝ Input: profile function-name. Return index, or zero when rejected.
 Z←0
 →(2≠⍴X)/0
 P←⊃X[1]
 F←⊃X[2]
 →(5≠⍴P)/0
 →(3≠⎕NC F)/0
 I←1
LOOP:→(I>⍴AgentProfiles)/ADD
 →((⊃P[1])≡⊃(⊃AgentProfiles[I])[1])/0
 I←I+1
 →LOOP
ADD:AgentProfiles←AgentProfiles,⊂P
 AgentFunctions←AgentFunctions,⊂F
 Z←⍴AgentProfiles
∇

∇ Z←MeanAgent Request;X
 X←⊃Request[1]
 Z←⍬
 →(0=⍴X)/0
 Z←,(+/X)÷⍴X
∇

∇ Z←MedianAgent Request;X;N;S
 X←⊃Request[1]
 Z←⍬
 N←⍴X
 →(N=0)/0
 S←X[⍋X]
 Z←,0.5×S[⌈N÷2]+S[1+⌊N÷2]
∇

∇ Z←TrimmedAgent Request;X;N;Drop;S
 X←⊃Request[1]
 Z←⍬
 N←⍴X
 →(N=0)/0
 Drop←⌊N÷5
 S←X[⍋X]
 S←Drop↓(-Drop)↓S
 Z←,(+/S)÷⍴S
∇

∇ Z←MidrangeAgent Request;X
 X←⊃Request[1]
 Z←⍬
 →(0=⍴X)/0
 Z←,0.5×(⌊/X)+⌈/X
∇

∇ Z←WinsorAgent Request;X;N;S;D;Low;High
 X←⊃Request[1]
 Z←⍬
 N←⍴X
 →(N=0)/0
 S←X[⍋X]
 D←⌊N÷5
 Low←S[1+D]
 High←S[N-D]
 S←Low⌈High⌊X
 Z←,(+/S)÷N
∇

∇ Z←ConsensusAgent Request;X;Prior;I;Values
 X←⊃Request[1]
 Prior←⊃Request[2]
 →(0=⍴Prior)/FIRST
 Values←⍬
 I←1
LOOP:→(I>⍴Prior)/DONE
 Values←Values,⊃Prior[I]
 I←I+1
 →LOOP
DONE:Z←MedianAgent (⊂Values),(⊂⍬),⊂1
 →0
FIRST:Z←MedianAgent Request
∇

∇ Z←WeightedMean X;Weights;Values;I;Width;P
 ⍝ Input: weights and nested proposals. Reject incompatible dimensions.
 Z←⍬
 Weights←⊃X[1]
 Values←⊃X[2]
 →(0=⍴Values)/0
 →((⍴Weights)≠⍴Values)/0
 →(∨/Weights<0)/0
 →((+/Weights)≤0)/0
 Width←⍴⊃Values[1]
 →(Width=0)/0
 P←Width⍴0
 I←1
LOOP:→(I>⍴Values)/DONE
 →(Width≠⍴⊃Values[I])/0
 P←P+Weights[I]×⊃Values[I]
 I←I+1
 →LOOP
DONE:Z←P÷+/Weights
∇
