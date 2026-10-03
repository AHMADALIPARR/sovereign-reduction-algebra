NB. SUBLEQ bi-encoder. Not softmax attention. Not a trained model.
NB. Weights are a fixed permutation, not fit by a loop.
NB. Every tensor entry is an extended integer. Float results abort.
NB. Unmasked head is Q +/ .* |:K and must equal A +/ .* B.
NB. Routed head masks dot-product factors with the SUBLEQ predicate.
NB. Goldilocks p = 2^64 - 2^32 + 1, residue via extended integers.

P =: 18446744069414584321x
GSAFE =: 65537x
LCGA =: 48271x
LCGM =: 2147483647x
SEED0 =: 20261002x
RADIX =: 5x
HALF =: P <.@% 2x

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

NB. Refuse IEEE float / complex. Machine int, boolean, extended are exact.
require_exact =: 3 : 0
  t =. 3!:0 y
  if. t e. 8 16 do.
    echo 'FLOAT_REFUSED'
    echo ": t
    exit 1
  end.
  x: y
)

mm =: 4 : 'require_exact x +/ .* y'
fmm =: 4 : 'P | x mm y'

NB. x is count (machine int). y is extended seed. Draw radix|lcg.
lcg_draw =: 4 : 0
  seed =. y
  buf =. 0 $ 0x
  for. i. x do.
    seed =. LCGM | LCGA * seed
    buf =. buf , RADIX | seed
  end.
  buf ; seed
)

NB. SUBLEQ: subtract, compare, predicate, select, route, reduce.
NB. Returns routed_dot ; aggregate ; predicate ; selected_count
subleq =: 4 : 0
  diff =. require_exact y - x
  pred =. require_exact diff <: 0
  selected =. pred # diff
  routed =. pred * diff
  agg =. require_exact +/ routed
  dot =. require_exact +/ pred * x * y
  dot ; agg ; pred ; (# selected)
)

field_routed =: 4 : 0
  diff =. P | require_exact y - x
  signed =. require_exact diff - P * x: (diff > HALF)
  pred =. require_exact signed <: 0
  terms =. pred * P | require_exact x * y
  P | require_exact +/ terms
)

pair_mat =: 1 : 0
  rows =. 0 $ a:
  for_q. x do.
    row =. 0 $ 0x
    for_k. y do.
      row =. row , q u k
    end.
    rows =. rows , < row
  end.
  > rows
)

dot_of =: 3 : '> 0 { y'
agg_of =: 3 : '> 1 { y'
pred_of =: 3 : '> 2 { y'

predict =: (dot_of @: subleq) pair_mat
aggs =: (agg_of @: subleq) pair_mat

pred_rows =: 4 : 0
  rows =. 0 $ a:
  for_q. x do.
    for_k. y do.
      rows =. rows , < pred_of q subleq k
    end.
  end.
  > rows
)

field_predict =: field_routed pair_mat

NB. x is A ; B, y is the shared weight matrix (extended).
run =: 4 : 0
  'a b' =. x
  w =. require_exact y
  q =. a mm w
  k =. (|: b) mm w
  exact =. q mm |: k
  ref =. a mm b
  pr =. q predict k
  ag =. q aggs k
  pd =. q pred_rows k
  err =. require_exact >./ | , pr - ref
  match =. *./ , exact = ref
  q ; k ; pr ; exact ; ref ; ag ; pd ; err ; match
)

frun =: 4 : 0
  'a b' =. x
  w =. y
  q =. a fmm w
  k =. (|: b) fmm w
  exact =. q fmm |: k
  ref =. a fmm b
  pr =. q field_predict k
  pr ; exact ; ref
)

PERM =: require_exact 4 4 $ 0 1 0 0 0 0 1 0 0 0 0 1 1 0 0 0
ID4 =: require_exact =/~ i. 4
perm_ok =: *./ , (PERM mm |: PERM) = ID4

'av seed2' =: 16 lcg_draw SEED0
'bv seed3' =: 16 lcg_draw > seed2
A =: require_exact 4 4 $ av
B =: require_exact 4 4 $ bv
'Q Ktow PR EX REF AG PD ERR MATCH' =: (A ; B) run PERM
GS =: GSAFE | PR
shapes_ok =: (4 4 -: $ A) *. (4 4 -: $ B) *. (4 4 -: $ PR) *. (4 4 -: $ EX) *. (4 4 -: $ REF)

'FSPR FSEX FSREF' =: (A ; B) frun PERM
fs_agrees =: (*./ , FSPR = PR) *. (*./ , FSEX = EX) *. (*./ , FSREF = REF)

LA =: 4 4 $ (P - 2x), 4x, 1x, 7x, 3x, (P - 5x), 2x, 9x, 8x, 1x, (P - 1x), 6x, 0x, 5x, 4x, (P - 3x)
LB =: 4 4 $ (P - 4x), 2x, 3x, 1x, 6x, (P - 1x), 0x, 5x, 1x, 8x, (P - 6x), 2x, 7x, 3x, 4x, (P - 2x)
'FLPR FLEX FLREF' =: (LA ; LB) frun PERM
fl_match =: *./ , FLEX = FLREF

HA =: require_exact 2 3 $ 1 2 3 4 0 1
HB =: require_exact 3 2 $ 1 2 0 1 2 1
HW =: require_exact =/~ i. 3
'HQ HK HPR HEX HREF HAG HPD HERR HMATCH' =: (HA ; HB) run HW

echo 'BIENCODER_V1'
echo 'ENGINE'
echo 'J'
echo 'J_VERSION'
echo 9!:14''
echo 'M'
shows 4
echo 'K'
shows 4
echo 'N'
shows 4
echo 'SEED'
shows SEED0
echo 'RADIX'
shows RADIX
echo 'A'
show A
echo 'B'
show B
echo 'WQ'
show PERM
echo 'WK'
show PERM
echo 'Q'
show Q
echo 'KTOWER'
show Ktow
echo 'PREDICTED'
show PR
echo 'EXACT_HEAD'
show EX
echo 'REFERENCE'
show REF
echo 'AGGREGATES'
show AG
echo 'PREDICATES'
show PD
echo 'GSAFE_PREDICTED'
show GS
echo 'MAX_ABS_ERROR'
shows ERR
echo 'EXACT_HEAD_MATCH'
shows MATCH
echo 'PERMUTATION_INVERSE'
shows perm_ok
echo 'SHAPES_OK'
shows shapes_ok
echo 'NOT_SOFTMAX'
shows 1
echo 'GOLDILOCKS_P'
shows P
echo 'FIELD_SMALL_PREDICTED'
show FSPR
echo 'FIELD_SMALL_EXACT_HEAD'
show FSEX
echo 'FIELD_SMALL_REFERENCE'
show FSREF
echo 'FIELD_SMALL_AGREES'
shows fs_agrees
echo 'FIELD_LARGE_PREDICTED'
show FLPR
echo 'FIELD_LARGE_EXACT_HEAD'
show FLEX
echo 'FIELD_LARGE_REFERENCE'
show FLREF
echo 'FIELD_LARGE_EXACT_MATCH'
shows fl_match
echo 'HAND_PREDICTED'
show HPR
echo 'HAND_EXACT_HEAD'
show HEX
echo 'HAND_REFERENCE'
show HREF
echo 'HAND_MAX_ABS_ERROR'
shows HERR
echo 'HAND_EXACT_HEAD_MATCH'
shows HMATCH
exit 0
