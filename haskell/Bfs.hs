{-# LANGUAGE BangPatterns #-}

-- BFS benchmark
-- Integer widths: Word32 for node IDs/offsets/adjacency, Int64 for distances.
module Main where

import qualified Data.ByteString.Char8 as BS
import Data.Int (Int64)
import qualified Data.Vector.Unboxed.Mutable as MV
import Data.Word (Word32)
import Numeric (showFFloat)
import System.Clock (Clock (Monotonic), getTime, toNanoSecs)
import System.Environment (getArgs)

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
        _ -> putStrLn "Usage: bfs <graph_file>"

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
            | i >= m = return rem
            | otherwise = do
                let (!u, r2) = readInt rem
                    (!v, r3) = readInt r2
                MV.write buf (2 * i) (i2w u)
                MV.write buf (2 * i + 1) (i2w v)
                MV.read deg u >>= MV.write deg u . (+ 1)
                MV.read deg v >>= MV.write deg v . (+ 1)
                readEdges buf r3 (i + 1)

    edgeBuf <- MV.new (2 * m) :: IO (MV.IOVector Word32)
    _ <- readEdges edgeBuf r1 0

    -- Build CSR
    offset <- MV.new (n + 1) :: IO (MV.IOVector Word32)
    MV.write offset 0 0
    let buildOffset !i
            | i >= n = return ()
            | otherwise = do
                !prev <- MV.read offset i
                !d <- MV.read deg i
                MV.write offset (i + 1) (prev + d)
                buildOffset (i + 1)
    buildOffset 0

    total <- MV.read offset n
    adj <- MV.new (w2i total) :: IO (MV.IOVector Word32)
    pos <- MV.replicate n (0 :: Word32)

    let fillAdj !i
            | i >= m = return ()
            | otherwise = do
                !u <- MV.read edgeBuf (2 * i)
                !v <- MV.read edgeBuf (2 * i + 1)
                let !ui = w2i u
                    !vi = w2i v
                !ou <- MV.read offset ui
                !pu <- MV.read pos ui
                MV.write adj (w2i (ou + pu)) v
                MV.write pos ui (pu + 1)
                !ov <- MV.read offset vi
                !pv <- MV.read pos vi
                MV.write adj (w2i (ov + pv)) u
                MV.write pos vi (pv + 1)
                fillAdj (i + 1)
    fillAdj 0

    t1 <- getTime Monotonic
    let readMs = fromIntegral (toNanoSecs t1 - toNanoSecs t0) / 1e6 :: Double

    -- ── Compute ──────────────────────────────────────────────────────────
    t2 <- getTime Monotonic

    visited <- MV.replicate n False
    dist <- MV.replicate n (0 :: Int64)
    queue <- MV.new n :: IO (MV.IOVector Word32)
    MV.write visited 0 True
    MV.write queue 0 0

    let bfs !qh !qt !dsum
            | qh >= qt = return (qt, dsum)
            | otherwise = do
                !v <- MV.read queue qh
                let !vi = w2i v
                !lo <- MV.read offset vi
                !hi <- MV.read offset (vi + 1)
                !dv <- MV.read dist vi
                let inner !j !qt' !ds
                        | j >= hi = bfs (qh + 1) qt' ds
                        | otherwise = do
                            !w <- MV.read adj (w2i j)
                            let !wi = w2i w
                            !vis <- MV.read visited wi
                            if vis
                                then inner (j + 1) qt' ds
                                else do
                                    MV.write visited wi True
                                    let !dw = dv + 1
                                    MV.write dist wi dw
                                    MV.write queue qt' w
                                    inner (j + 1) (qt' + 1) (ds + dw)
                inner lo qt dsum
    (!nvisited, !distSum) <- bfs 0 1 0

    t3 <- getTime Monotonic
    let computeMs = fromIntegral (toNanoSecs t3 - toNanoSecs t2) / 1e6 :: Double

    putStrLn $
        "read="
            ++ showFFloat (Just 1) readMs ""
            ++ "ms compute="
            ++ showFFloat (Just 1) computeMs ""
            ++ "ms checksum="
            ++ show distSum
            ++ " visited="
            ++ show nvisited
