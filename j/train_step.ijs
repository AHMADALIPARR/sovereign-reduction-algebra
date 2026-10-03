NB. One integer training step. Not softmax. Not a training framework.
NB. Forward nodes, in order: subtract, compare, predicate, select, route, reduce.
NB. Wq and Wk stay the fixed permutation. The unmasked head stays A times B.
NB. The routed residual (exact product minus routed prediction) is added once
NB. to an integer projection, then that projection is added elementwise to
NB. the routed prediction. The unmasked head is not changed.
NB. No weight update, no floor, no modulus. Extended integers only.
NB. AGPL-3.0 only. Do not use MIT.

this =. > {: 4!:3 ''
dir =. (>: this i: '/') {. this
load dir , 'sha512.ijs'

P =: 18446744069414584321x
LCGA =: 48271x
LCGM =: 2147483647x
SEED0 =: 20261002x
RADIX =: 5x
KNOWN =: 4 4 $ 18x 18x 12x 16x 23x 22x 12x 19x 19x 29x 18x 29x 6x 15x 10x 15x
PRE_SEAL_WANT =: 'e6b4a8fda2cde450bd3d9c2b14932136b2894e2b78a1d6c91c52681ec06f3bd7f13e660a655ca84171ccb77584cc0729792c2123ab5b4b758e74576323756f6e'

show =: 3 : 0
  raw =. ": y
  shp =. $ raw
  s =. '-' (I. , raw = '_') } , raw
  echo shp $ s
)

shows =: 3 : 0
  s =. , ": y
  echo '-' (I. s = '_') } s
)

require_exact =: 3 : 0
  t =. 3!:0 y
  if. t e. 8 16 do.
    echo 'FLOAT_REFUSED'
    exit 1
  end.
  x: y
)

mm =: 4 : 'require_exact x +/ .* y'

lcg_draw =: 4 : 0
  seed =. y
  buf =. 0 $ 0x
  for. i. x do.
    seed =. LCGM | LCGA * seed
    buf =. buf , RADIX | seed
  end.
  buf ; seed
)

NB. Forward DAG. x is q, y is k unless noted.
fwd_subtract =: 4 : 'require_exact y - x'
fwd_compare =: 3 : 'require_exact y <: 0'
fwd_predicate =: 3 : 'require_exact y'
fwd_select =: 3 : ', I. y > 0'
fwd_route =: 4 : 0
  'q k' =. x
  idx =. y
  prod =. require_exact q * k
  terms =. (# prod) $ 0x
  if. 0 < # idx do.
    terms =. (idx { prod) idx } terms
  end.
  require_exact terms
)
fwd_reduce =: 3 : 'require_exact +/ y'

NB. Wq and Wk stay the permutation. The routed residual updates only the
NB. integer projection between the unmasked head and the routed prediction.
NB. Projection before the step is 0. One step adds (exact product - routed),
NB. elementwise, extended integers, no floor and no modulus.
NB. Extended integers only. AGPL-3.0 only. Do not use MIT.

predict_nodes =: 4 : 0
  Q =. x
  K =. y
  PR =. ((# Q), (# K)) $ 0x
  for_qi. i. # Q do.
    for_kj. i. # K do.
      q =. qi { Q
      k =. kj { K
      diff =. q fwd_subtract k
      cmp =. fwd_compare diff
      pred =. fwd_predicate cmp
      idx =. fwd_select pred
      routed =. (q ; k) fwd_route idx
      yv =. fwd_reduce routed
      PR =. yv (<qi, kj) } PR
    end.
  end.
  require_exact PR
)

NB. x is a message. y is a boolean. Control words stay inside an explicit verb.
assert =: 4 : 0
  if. -. y do.
    echo 'TRAIN_STEP_FAIL'
    echo x
    exit 1
  end.
  1
)

PERM =: require_exact 4 4 $ 0 1 0 0 0 0 1 0 0 0 0 1 1 0 0 0
'av seed2' =: 16 lcg_draw SEED0
'bv seed3' =: 16 lcg_draw > seed2
A =: require_exact 4 4 $ av
B =: require_exact 4 4 $ bv
WQ =: PERM
WK =: PERM
Q =: A mm WQ
K =: (|: B) mm WK
EX =: Q mm |: K
REF =: A mm B
PR =: Q predict_nodes K
RES =: require_exact EX - PR
LOSS =: require_exact +/ | , RES
ERR =: require_exact >./ | , PR - REF
PROJ0 =: require_exact ($ EX) $ 0x
PROJ =: require_exact PROJ0 + RES
'pre exact head mismatch' assert *./ , EX = REF
'pre exact head is not the known product' assert EX -: KNOWN
'pre max abs error is not 15' assert ERR -: 15x
'Wq moved' assert WQ -: PERM
'Wk moved' assert WK -: PERM
PRE_SEAL =: dag_seal_hex EX ; PR ; PERM ; P
'pre seal mismatch' assert PRE_SEAL -: PRE_SEAL_WANT

NB. Unmasked head stays the frozen-weight product. It is not multiplied
NB. by the projection. The post routed prediction is the pre routed
NB. prediction plus the projection, elementwise.
Q2 =: A mm WQ
K2 =: (|: B) mm WK
EX2 =: Q2 mm |: K2
PR2 =: require_exact PR + PROJ
REF2 =: A mm B
ERR2 =: require_exact >./ | , PR2 - REF2
PRE_MATCH =: require_exact *./ , EX = REF
POST_MATCH =: require_exact *./ , EX2 = REF2
'post exact head mismatch' assert POST_MATCH -: 1x
'post Wq moved' assert WQ -: PERM
'post Wk moved' assert WK -: PERM
NB. Seal post-step tensors: exact head, routed prediction, then Wq, Wk, projection.
WT =: WQ , WK , PROJ
SEAL =: dag_seal_hex EX2 ; PR2 ; WT ; P
VOK =: require_exact SEAL verify_dag EX2 ; PR2 ; WT ; P
'post seal verify' assert VOK -: 1x

echo 'TRAIN_STEP_V1'
echo 'ENGINE'
echo 'J'
echo 'M'
shows 4
echo 'K'
shows 4
echo 'N'
shows 4
echo 'D'
shows 4
echo 'SEED'
shows SEED0
echo 'A'
show A
echo 'B'
show B
echo 'WQ'
show WQ
echo 'WK'
show WK
echo 'PROJ_BEFORE'
show PROJ0
echo 'PROJ_AFTER'
show PROJ
echo 'PRE_EXACT_HEAD'
show EX
echo 'PRE_PREDICTED'
show PR
echo 'PRE_REFERENCE'
show REF
echo 'RESIDUAL'
show RES
echo 'LOSS'
shows LOSS
echo 'POST_EXACT_HEAD'
show EX2
echo 'POST_PREDICTED'
show PR2
echo 'POST_REFERENCE'
show REF2
echo 'PRE_MAX_ABS_ERROR'
shows ERR
echo 'POST_MAX_ABS_ERROR'
shows ERR2
echo 'PRE_EXACT_HEAD_MATCH'
shows PRE_MATCH
echo 'POST_EXACT_HEAD_MATCH'
shows POST_MATCH
echo 'NOT_SOFTMAX'
shows 1
echo 'PRE_SEAL'
echo PRE_SEAL
echo 'SEAL'
echo SEAL
echo 'VERIFY'
shows VOK
exit 0
