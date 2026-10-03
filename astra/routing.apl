⍝ Astra APL: deterministic capability and budget routing.
⍝ All indices are one-origin. No external routing framework is used.
⍝ A profile is (name capabilities keywords cost enabled).

∇ Z←Lower X;U;L;I;M
 U←'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
 L←'abcdefghijklmnopqrstuvwxyz'
 Z←,X
 I←U⍳Z
 M←I≤⍴U
 Z[M/⍳⍴Z]←L[M/I]
∇

∇ Z←Tokens X;S;A;I;W
 S←Lower X
 A←'abcdefghijklmnopqrstuvwxyz0123456789_'
 Z←⍬
 W←''
 I←1
LOOP:→(I>⍴S)/END
 →(~S[I]∊A)/BREAK
 W←W,S[I]
 →NEXT
BREAK:→(0=⍴W)/NEXT
 Z←Z,⊂W
 W←''
NEXT:I←I+1
 →LOOP
END:→(0=⍴W)/0
 Z←Z,⊂W
∇

∇ Z←Unique X;I
 Z←⍬
 I←1
LOOP:→(I>⍴X)/0
 →(∨/X[I]∊Z)/NEXT
 Z←Z,X[I]
NEXT:I←I+1
 →LOOP
∇

∇ Z←Profile X;N;C;K;V;E
 ⍝ Construct a validated profile from a five-element nested vector.
 Z←⍬
 →(5≠⍴X)/0
 N←⊃X[1]
 C←⊃X[2]
 K←⊃X[3]
 V←⊃X[4]
 E←⊃X[5]
 →(0=⍴N)/0
 →(1≠≡V)/0
 →(V≤0)/0
 →(~E∊0 1)/0
 Z←(⊂N),(⊂Unique C),(⊂Unique Tokens K),(⊂V),⊂E
∇

∇ Z←Required Eligible P;Caps
 Caps←⊃P[2]
 Z←(⊃P[5])∧∧/Required∊Caps
∇

∇ Z←Normalize X;T
 Z←0×X
 →(0=⍴X)/0
 T←+/X
 →(T≤0)/0
 Z←X÷T
∇

∇ Z←Profiles Route Request;Text;Need;Want;K;Budget;Excluded;Query;Used;Covered;IDs;Scores;Spent;Matches;NewCaps;I;P;Cost;Score;Utility;Best;BestUtility;BestScore;BestCost;Tie;Weights
 ⍝ Request: prompt required preferred top-k budget excluded-indices.
 ⍝ Result: selected-indices weights raw-scores total-cost.
 Text←⊃Request[1]
 Need←⊃Request[2]
 Want←⊃Request[3]
 K←⊃Request[4]
 Budget←⊃Request[5]
 Excluded←⊃Request[6]
 Query←Unique Tokens Text
 Used←Excluded
 Covered←⍬
 IDs←⍬
 Scores←⍬
 Spent←0
 Z←(⊂IDs),(⊂IDs),(⊂IDs),⊂Spent
 →((K≤0)∨K≠⌊K)/0
 →(Budget≤0)/0
ROUND:→((⍴IDs)≥K)/DONE
 Best←0
 BestUtility←¯1
 BestScore←0
 BestCost←0
 I←1
SCAN:→(I>⍴Profiles)/CHOOSE
 →(I∊Used)/NEXT
 P←⊃Profiles[I]
 →(~Need Eligible P)/NEXT
 Cost←⊃P[4]
 →(Cost>Budget-Spent)/NEXT
 Matches←+/Query∊⊃P[3]
 NewCaps←((⊃P[2])∊Want)∧~(⊃P[2])∊Covered
 Score←1+(2×Matches÷1⌈⍴Query)+3×+/NewCaps
 Utility←Score÷Cost
 →(Utility>BestUtility)/KEEP
 →(Utility<BestUtility)/NEXT
 →(Cost<BestCost)/KEEP
 →(Cost>BestCost)/NEXT
 ⍝ Stable registration order is the final tie breaker.
 →NEXT
KEEP:Best←I
 BestUtility←Utility
 BestScore←Score
 BestCost←Cost
NEXT:I←I+1
 →SCAN
CHOOSE:→(Best=0)/DONE
 IDs←IDs,Best
 Scores←Scores,BestScore
 Used←Used,Best
 P←⊃Profiles[Best]
 Covered←Unique Covered,⊃P[2]
 Spent←Spent+BestCost
 →ROUND
DONE:Weights←Normalize Scores
 Z←(⊂IDs),(⊂Weights),(⊂Scores),⊂Spent
∇
