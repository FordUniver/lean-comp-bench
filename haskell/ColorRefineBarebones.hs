{-# LANGUAGE BangPatterns #-}
-- Color refinement (1-WL) benchmark — barebones (mutable unboxed vectors, unsafeRead/unsafeWrite)
-- Integer widths: Word32 for node IDs/offsets/colors, Word64 for hashes, Int64 for checksum.
module Main where

import qualified Data.ByteString.Char8 as BS
import qualified Data.Vector.Unboxed.Mutable as MV
import qualified Data.HashMap.Strict as HM
import Data.Int (Int64)
import Data.Word (Word32, Word64)
import Data.Bits (xor)
import System.Environment (getArgs)
import System.Clock (getTime, Clock(Monotonic), toNanoSecs)
import Numeric (showFFloat)

readInt :: BS.ByteString -> (Int, BS.ByteString)
readInt !bs = case BS.readInt (BS.dropWhile (< '0') bs) of
    Just (!n, !rest) -> (n, rest)
    Nothing -> error "parse error"

i2w :: Int -> Word32
i2w = fromIntegral
{-# INLINE i2w #-}

w2i :: Word32 -> Int
w2i = fromIntegral
{-# INLINE w2i #-}

main :: IO ()
main = do
    args <- getArgs
    case args of
      [file] -> run file
      _ -> putStrLn "Usage: color_refine_barebones <graph_file>"

run :: FilePath -> IO ()
run file = do
    -- ── Read ─────────────────────────────────────────────────────────────
    t0 <- getTime Monotonic
    contents <- BS.readFile file

    let (!n, r0) = readInt contents
        (!m, r1) = readInt r0

    -- Count degrees
    deg <- MV.replicate n (0 :: Word32)
    let readEdges !buf !rem !i
          | i >= m    = return rem
          | otherwise = do
              let (!u, r2) = readInt rem
                  (!v, r3) = readInt r2
              MV.unsafeWrite buf (2*i) (i2w u)
              MV.unsafeWrite buf (2*i+1) (i2w v)
              MV.unsafeRead deg u >>= MV.unsafeWrite deg u . (+1)
              MV.unsafeRead deg v >>= MV.unsafeWrite deg v . (+1)
              readEdges buf r3 (i+1)

    edgeBuf <- MV.new (2*m) :: IO (MV.IOVector Word32)
    _ <- readEdges edgeBuf r1 0

    -- Build CSR
    offset <- MV.new (n+1) :: IO (MV.IOVector Word32)
    MV.unsafeWrite offset 0 0
    let buildOffset !i
          | i >= n    = return ()
          | otherwise = do
              !prev <- MV.unsafeRead offset i
              !d    <- MV.unsafeRead deg i
              MV.unsafeWrite offset (i+1) (prev + d)
              buildOffset (i+1)
    buildOffset 0

    total <- MV.unsafeRead offset n
    adj <- MV.new (w2i total) :: IO (MV.IOVector Word32)
    pos <- MV.replicate n (0 :: Word32)

    let fillAdj !i
          | i >= m    = return ()
          | otherwise = do
              !u <- MV.unsafeRead edgeBuf (2*i)
              !v <- MV.unsafeRead edgeBuf (2*i+1)
              let !ui = w2i u
                  !vi = w2i v
              !ou <- MV.unsafeRead offset ui
              !pu <- MV.unsafeRead pos ui
              MV.unsafeWrite adj (w2i (ou+pu)) v
              MV.unsafeWrite pos ui (pu+1)
              !ov <- MV.unsafeRead offset vi
              !pv <- MV.unsafeRead pos vi
              MV.unsafeWrite adj (w2i (ov+pv)) u
              MV.unsafeWrite pos vi (pv+1)
              fillAdj (i+1)
    fillAdj 0

    t1 <- getTime Monotonic
    let readMs = fromIntegral (toNanoSecs t1 - toNanoSecs t0) / 1e6 :: Double

    -- ── Compute ──────────────────────────────────────────────────────────
    t2 <- getTime Monotonic

    color <- MV.replicate n (0 :: Word32)
    newColor <- MV.new n :: IO (MV.IOVector Word32)
    sigHash <- MV.new n :: IO (MV.IOVector Word64)

    -- Find max degree for reusable buffer
    let findMaxDeg !v !mx
          | v >= n    = return mx
          | otherwise = do
              !lo <- MV.unsafeRead offset v
              !hi <- MV.unsafeRead offset (v+1)
              let !d = w2i (hi - lo)
              findMaxDeg (v+1) (max mx d)
    !maxDeg <- findMaxDeg 0 0
    nbuf <- MV.new maxDeg :: IO (MV.IOVector Word32)

    let refine !round !prevRounds !prevColors
          | round >= n = return (prevRounds, prevColors)
          | otherwise = do
              -- Build signature hash for each vertex
              let hashVertex !v
                    | v >= n    = return ()
                    | otherwise = do
                        !lo <- MV.unsafeRead offset v
                        !hi <- MV.unsafeRead offset (v+1)
                        let !degV = w2i (hi - lo)
                        -- Collect neighbor colors
                        let collectNbr !j
                              | j >= degV = return ()
                              | otherwise = do
                                  !w <- MV.unsafeRead adj (w2i lo + j)
                                  !c <- MV.unsafeRead color (w2i w)
                                  MV.unsafeWrite nbuf j c
                                  collectNbr (j+1)
                        collectNbr 0
                        -- Sort neighbor colors in-place (insertion sort)
                        let insertSort !i
                              | i >= degV = return ()
                              | otherwise = do
                                  !key <- MV.unsafeRead nbuf i
                                  let shift !j
                                        | j <= 0    = MV.unsafeWrite nbuf j key >> insertSort (i+1)
                                        | otherwise = do
                                            !prev <- MV.unsafeRead nbuf (j-1)
                                            if prev > key
                                              then MV.unsafeWrite nbuf j prev >> shift (j-1)
                                              else MV.unsafeWrite nbuf j key >> insertSort (i+1)
                                  shift i
                        insertSort 1
                        -- Hash
                        !cv <- MV.unsafeRead color v
                        let !h0' = fromIntegral cv * 1000003 :: Word64
                            !h0  = (h0' `xor` (fromIntegral degV * 2654435761)) * 1000003
                        let hashNbr !j !h
                              | j >= degV = return h
                              | otherwise = do
                                  !nc <- MV.unsafeRead nbuf j
                                  let !h' = (h `xor` (fromIntegral nc * 2654435761)) * 1000003
                                  hashNbr (j+1) h'
                        !hv <- hashNbr 0 h0
                        MV.unsafeWrite sigHash v hv
                        hashVertex (v+1)
              hashVertex 0

              -- Map hashes to consecutive colors
              let buildMapping !v !nextId !mp
                    | v >= n    = return (nextId, mp)
                    | otherwise = do
                        !h <- MV.unsafeRead sigHash v
                        case HM.lookup h mp of
                          Just !cid -> do
                            MV.unsafeWrite newColor v cid
                            buildMapping (v+1) nextId mp
                          Nothing -> do
                            MV.unsafeWrite newColor v nextId
                            buildMapping (v+1) (nextId+1) (HM.insert h nextId mp)
              (!nColors, _) <- buildMapping 0 0 HM.empty

              -- Check stability
              let checkStable !v
                    | v >= n    = return True
                    | otherwise = do
                        !c <- MV.unsafeRead color v
                        !nc <- MV.unsafeRead newColor v
                        if c /= nc then return False
                        else checkStable (v+1)
              !stable <- checkStable 0

              let !thisRound = round + 1
              if stable
                then return (thisRound, nColors)
                else do
                  -- Copy newColor -> color
                  MV.unsafeCopy color newColor
                  refine (round+1) thisRound nColors

    (!rounds, !numColors) <- refine 0 0 0

    -- Compute checksum
    let sumColors !v !s
          | v >= n    = return s
          | otherwise = do
              !c <- MV.unsafeRead color v
              sumColors (v+1) (s + fromIntegral c)
    !checksum <- sumColors 0 (0 :: Int64)

    t3 <- getTime Monotonic
    let computeMs = fromIntegral (toNanoSecs t3 - toNanoSecs t2) / 1e6 :: Double

    putStrLn $ "read=" ++ showFFloat (Just 1) readMs "" ++ "ms compute="
              ++ showFFloat (Just 1) computeMs "" ++ "ms rounds=" ++ show rounds
              ++ " colors=" ++ show numColors ++ " checksum=" ++ show checksum
