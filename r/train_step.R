# One integer training step. Not softmax. Not a training framework.
# Forward nodes, in order: subtract, compare, predicate, select, route, reduce.
# Wq and Wk stay the fixed permutation. The unmasked head stays A times B.
# The routed residual (exact product minus routed prediction) is added once
# to an integer projection, then that projection is added elementwise to
# the routed prediction. The unmasked head is not changed.
# No weight update, no floor, no modulus. gmp bigz only.
# AGPL-3.0 only. Do not use MIT.

userlib <- path.expand("~/R/library")
if (dir.exists(userlib)) .libPaths(c(userlib, .libPaths()))
suppressPackageStartupMessages(library(gmp))

cmd_args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", cmd_args, value = TRUE)
this_file <- sub("^--file=", "", file_arg[[1]])
source(file.path(dirname(normalizePath(this_file)), "sha512.R"))

P <- as.bigz("18446744069414584321")
LCGA <- as.bigz("48271")
LCGM <- as.bigz("2147483647")
SEED0 <- as.bigz("20261002")
RADIX <- as.bigz("5")
PRE_SEAL_WANT <- "e6b4a8fda2cde450bd3d9c2b14932136b2894e2b78a1d6c91c52681ec06f3bd7f13e660a655ca84171ccb77584cc0729792c2123ab5b4b758e74576323756f6e"

refuse_double <- function(M, where) {
  if (is.double(M) || inherits(M, "numeric")) {
    if (!inherits(M, "bigz")) stop(paste("FLOAT_REFUSED", where), call. = FALSE)
  }
  if (!inherits(M, "bigz")) stop(paste("NOT_BIGZ", where), call. = FALSE)
  M
}

as_mat <- function(chars, nr, nc) {
  if (any(grepl("[^0-9-]", chars))) stop("non-digit matrix entry", call. = FALSE)
  refuse_double(as.bigz(base::matrix(chars, nrow = nr, ncol = nc, byrow = TRUE)), "as_mat")
}

zeros <- function(nr, nc) as_mat(rep("0", nr * nc), nr, nc)

zvec <- function(n) {
  v <- as.bigz(rep("0", n))
  if (!inherits(v, "bigz")) stop("NOT_BIGZ zvec", call. = FALSE)
  v
}

transpose_z <- function(M) {
  refuse_double(M, "transpose_in")
  nr <- nrow(M)
  nc <- ncol(M)
  out <- zeros(nc, nr)
  for (i in seq_len(nr)) {
    for (j in seq_len(nc)) out[j, i] <- M[i, j]
  }
  refuse_double(out, "transpose_out")
}

mm <- function(A, B) {
  refuse_double(A, "mm.A")
  refuse_double(B, "mm.B")
  refuse_double(A %*% B, "mm.C")
}

lcg_step <- function(seed) mod.bigz(LCGA * seed, LCGM)

lcg_draw <- function(n, seed) {
  buf <- character(n)
  for (i in seq_len(n)) {
    seed <- lcg_step(seed)
    buf[i] <- as.character(mod.bigz(seed, RADIX))
  }
  list(vals = as.bigz(buf), seed = seed)
}

# Forward DAG.
fwd_subtract <- function(q, k) refuse_double(k - q, "subtract")

fwd_compare <- function(diff) {
  refuse_double(as.bigz(diff <= as.bigz("0")), "compare")
}

fwd_predicate <- function(cmp) refuse_double(as.bigz(cmp), "predicate")

fwd_select <- function(pred) which(pred != as.bigz("0"))

fwd_route <- function(q, k, idx) {
  prod <- refuse_double(q * k, "route_prod")
  terms <- zvec(length(prod))
  if (length(idx)) terms[idx] <- prod[idx]
  refuse_double(terms, "route")
}

fwd_reduce <- function(routed) refuse_double(sum(routed), "reduce")

pair_forward <- function(q, k) {
  diff <- fwd_subtract(q, k)
  cmp <- fwd_compare(diff)
  pred <- fwd_predicate(cmp)
  idx <- fwd_select(pred)
  routed <- fwd_route(q, k, idx)
  y <- fwd_reduce(routed)
  list(cmp = cmp, pred = pred, idx = idx, y = y)
}

predict_nodes <- function(Q, K) {
  pr <- zeros(nrow(Q), nrow(K))
  for (i in seq_len(nrow(Q))) {
    for (j in seq_len(nrow(K))) {
      nodes <- pair_forward(Q[i, ], K[j, ])
      pr[i, j] <- nodes$y
    }
  }
  refuse_double(pr, "predict")
}

stack_rows <- function(top, bottom) {
  out <- zeros(nrow(top) + nrow(bottom), ncol(top))
  for (i in seq_len(nrow(top))) {
    for (j in seq_len(ncol(top))) out[i, j] <- top[i, j]
  }
  for (i in seq_len(nrow(bottom))) {
    for (j in seq_len(ncol(bottom))) out[nrow(top) + i, j] <- bottom[i, j]
  }
  refuse_double(out, "stack")
}

sum_abs <- function(M) {
  loss <- as.bigz("0")
  for (i in seq_len(nrow(M))) {
    for (j in seq_len(ncol(M))) {
      d <- M[i, j]
      if (d < as.bigz("0")) d <- -d
      loss <- loss + d
    }
  }
  refuse_double(loss, "loss")
}

max_abs_diff <- function(A, B) {
  err <- as.bigz("0")
  for (i in seq_len(nrow(A))) {
    for (j in seq_len(ncol(A))) {
      d <- A[i, j] - B[i, j]
      if (d < as.bigz("0")) d <- -d
      if (d > err) err <- d
    }
  }
  refuse_double(err, "max_abs")
}

cat_line <- function(x) cat(as.character(x), "\n", sep = "")

cat_mat <- function(M) {
  refuse_double(M, "print")
  for (i in seq_len(nrow(M))) {
    cat(paste(as.character(M[i, ]), collapse = " "), "\n", sep = "")
  }
}

flag <- function(x) if (isTRUE(x)) "1" else "0"

fail <- function(msg) {
  cat("TRAIN_STEP_FAIL\n", msg, "\n", sep = "")
  quit(status = 1)
}

perm_chars <- c(
  "0", "1", "0", "0",
  "0", "0", "1", "0",
  "0", "0", "0", "1",
  "1", "0", "0", "0"
)
PERM <- as_mat(perm_chars, 4L, 4L)
drawn_a <- lcg_draw(16L, SEED0)
drawn_b <- lcg_draw(16L, drawn_a$seed)
A <- as_mat(as.character(drawn_a$vals), 4L, 4L)
B <- as_mat(as.character(drawn_b$vals), 4L, 4L)
Q <- mm(A, PERM)
K <- mm(transpose_z(B), PERM)
EX <- mm(Q, transpose_z(K))
REF <- mm(A, B)
PR <- predict_nodes(Q, K)
RES <- refuse_double(EX - PR, "residual")
LOSS <- sum_abs(RES)
ERR <- max_abs_diff(PR, REF)
known <- as_mat(c(
  "18", "18", "12", "16",
  "23", "22", "12", "19",
  "19", "29", "18", "29",
  "6", "15", "10", "15"
), 4L, 4L)
if (!all(EX == REF)) fail("pre exact head mismatch")
if (!all(EX == known)) fail("pre exact head is not the known product")
if (as.character(ERR) != "15") fail("pre max abs error is not 15")
PRE_SEAL <- dag_seal_hex(EX, PR, PERM, P)
if (!identical(PRE_SEAL, PRE_SEAL_WANT)) fail("pre seal mismatch")

# Wq and Wk stay the permutation. Projection starts at 0 and gains the residual.
WQ <- PERM
WK <- PERM
PROJ0 <- zeros(nrow(EX), ncol(EX))
PROJ <- refuse_double(PROJ0 + RES, "projection")
if (!all(WQ == PERM) || !all(WK == PERM)) fail("weights moved before recompute")

# Unmasked head stays the frozen-weight product. It is not multiplied by
# the projection. The post routed prediction is the pre routed prediction
# plus the projection, elementwise.
Q2 <- mm(A, WQ)
K2 <- mm(transpose_z(B), WK)
EX2 <- mm(Q2, transpose_z(K2))
PR2 <- refuse_double(PR + PROJ, "post_predicted")
REF2 <- mm(A, B)
ERR2 <- max_abs_diff(PR2, REF2)
if (!all(EX2 == REF2)) fail("post exact head mismatch")
if (!all(WQ == PERM) || !all(WK == PERM)) fail("weights moved")
# Seal post-step tensors: exact head, routed prediction, then Wq, Wk, projection.
WT <- stack_rows(stack_rows(WQ, WK), PROJ)
SEAL <- dag_seal_hex(EX2, PR2, WT, P)
VOK <- verify_dag(SEAL, EX2, PR2, WT, P)
if (!isTRUE(VOK)) fail("post seal verify")

cat("TRAIN_STEP_V1\n")
cat("ENGINE\nR\n")
cat("M\n4\nK\n4\nN\n4\nD\n4\n")
cat("SEED\n")
cat_line(SEED0)
cat("A\n"); cat_mat(A)
cat("B\n"); cat_mat(B)
cat("WQ\n"); cat_mat(WQ)
cat("WK\n"); cat_mat(WK)
cat("PROJ_BEFORE\n"); cat_mat(PROJ0)
cat("PROJ_AFTER\n"); cat_mat(PROJ)
cat("PRE_EXACT_HEAD\n"); cat_mat(EX)
cat("PRE_PREDICTED\n"); cat_mat(PR)
cat("PRE_REFERENCE\n"); cat_mat(REF)
cat("RESIDUAL\n"); cat_mat(RES)
cat("LOSS\n"); cat_line(LOSS)
cat("POST_EXACT_HEAD\n"); cat_mat(EX2)
cat("POST_PREDICTED\n"); cat_mat(PR2)
cat("POST_REFERENCE\n"); cat_mat(REF2)
cat("PRE_MAX_ABS_ERROR\n"); cat_line(ERR)
cat("POST_MAX_ABS_ERROR\n"); cat_line(ERR2)
cat("PRE_EXACT_HEAD_MATCH\n"); cat(flag(all(EX == REF)), "\n", sep = "")
cat("POST_EXACT_HEAD_MATCH\n"); cat(flag(all(EX2 == REF2)), "\n", sep = "")
cat("NOT_SOFTMAX\n1\n")
cat("PRE_SEAL\n"); cat(PRE_SEAL, "\n", sep = "")
cat("SEAL\n"); cat(SEAL, "\n", sep = "")
cat("VERIFY\n"); cat(flag(VOK), "\n", sep = "")
quit(status = 0)
