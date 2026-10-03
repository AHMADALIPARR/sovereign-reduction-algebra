⍝ Astra APL: bounded-round orchestration with budget accounting.
⍝ Execution is synchronous in GNU APL. No concurrency or preemption claim.

∇ Z←Function Invoke Request;Caught;Value
 ⍝ Function is a registered APL name, never text obtained from the prompt.
 Value←⍬
 Caught←⎕EC 'Value←',Function,' Request'
 Z←(⊂0),⊂⍬
 →(0=⊃Caught[1])/0
 →(0=⍴Value)/0
 Z←(⊂1),⊂Value
∇

∇ Z←Mixture Config;Prompt;Data;Need;Want;K;Budget;Rounds;Round;Spent;Excluded;Previous;History;Failures;Routes;Request;Decision;IDs;Weights;Good;GoodWeights;I;ID;Outcome;Function;Answer;Remaining
 ⍝ Config: prompt data required preferred top-k total-budget round-count.
 ⍝ Result: answer history routes failures spent success.
 Prompt←⊃Config[1]
 Data←⊃Config[2]
 Need←⊃Config[3]
 Want←⊃Config[4]
 K←⊃Config[5]
 Budget←⊃Config[6]
 Rounds←⊃Config[7]
 Round←1
 Spent←0
 Excluded←⍬
 Previous←⍬
 History←⍬
 Failures←⍬
 Routes←⍬
 Answer←⍬
 Z←(⊂Answer),(⊂History),(⊂Routes),(⊂Failures),(⊂Spent),⊂0
 →((Rounds≤0)∨Rounds≠⌊Rounds)/0
LOOP:→(Round>Rounds)/DONE
 Remaining←Budget-Spent
 →(Remaining≤0)/DONE
 Request←(⊂Prompt),(⊂Need),(⊂Want),(⊂K),(⊂Remaining),⊂Excluded
 Decision←AgentProfiles Route Request
 IDs←⊃Decision[1]
 Weights←⊃Decision[2]
 →(0=⍴IDs)/DONE
 Routes←Routes,⊂Decision
 Spent←Spent+⊃Decision[4]
 Good←⍬
 GoodWeights←⍬
 Request←(⊂Data),(⊂Previous),⊂Round
 I←1
AGENT:→(I>⍴IDs)/AGGREGATE
 ID←IDs[I]
 Function←⊃AgentFunctions[ID]
 Outcome←Function Invoke Request
 →(0=⊃Outcome[1])/FAIL
 Good←Good,Outcome[2]
 GoodWeights←GoodWeights,Weights[I]
 History←History,⊂(⊂Round),(⊂ID),Outcome[2]
 →NEXT
FAIL:Excluded←Unique Excluded,ID
 Failures←Failures,⊂Round ID
NEXT:I←I+1
 →AGENT
AGGREGATE:→(0=⍴Good)/ADVANCE
 Previous←Good
 Answer←WeightedMean (⊂GoodWeights),⊂Good
ADVANCE:Round←Round+1
 →LOOP
DONE:Z←(⊂Answer),(⊂History),(⊂Routes),(⊂Failures),(⊂Spent),⊂0<⍴Answer
∇
