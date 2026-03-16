{-# LANGUAGE BangPatterns #-}
-- Sorting benchmark: quicksort and mergesort on Word64 arrays (mutable IOVector)
-- LCG PRNG (Knuth) — identical across all languages

module Main where

import Data.Word (Word64)
import qualified Data.Vector.Unboxed.Mutable as MV
import qualified Data.Vector.Unboxed as V
import System.Environment (getArgs)
import System.Clock (getTime, Clock(Monotonic), toNanoSecs)

-- LCG PRNG
lcgNext :: Word64 -> (Word64, Word64)
lcgNext s = let s' = s * 6364136223846793005 + 1442695040888963407 in (s', s')

generateArray :: Int -> Word64 -> IO (MV.IOVector Word64)
generateArray n seed = do
    arr <- MV.new n
    let go !i !s
          | i >= n    = return arr
          | otherwise = let (!val, !s') = lcgNext s
                        in MV.write arr i val >> go (i+1) s'
    go 0 seed

-- Lomuto partition
partition :: MV.IOVector Word64 -> Int -> Int -> IO Int
partition arr lo hi = do
    pivot <- MV.read arr hi
    let go !j !i
          | j >= hi   = MV.swap arr i hi >> return i
          | otherwise = do
              v <- MV.read arr j
              if v <= pivot
                then MV.swap arr i j >> go (j+1) (i+1)
                else go (j+1) i
    go lo lo

quicksort :: MV.IOVector Word64 -> Int -> Int -> IO ()
quicksort arr lo hi
  | lo >= hi  = return ()
  | otherwise = do
      p <- partition arr lo hi
      quicksort arr lo (p - 1)
      quicksort arr (p + 1) hi

-- Mergesort (top-down recursive with temp buffer)
mergesortRec :: MV.IOVector Word64 -> MV.IOVector Word64 -> Int -> Int -> IO ()
mergesortRec arr buf lo hi
  | lo >= hi  = return ()
  | otherwise = do
      let mid = lo + (hi - lo) `div` 2
      mergesortRec arr buf lo mid
      mergesortRec arr buf (mid + 1) hi
      -- copy to buf
      let copyLoop !k
            | k > hi    = return ()
            | otherwise = MV.read arr k >>= MV.write buf k >> copyLoop (k+1)
      copyLoop lo
      -- merge back
      let mergeLoop !i !j !k
            | i > mid   = if j > hi then return ()
                          else MV.read buf j >>= MV.write arr k >> mergeLoop i (j+1) (k+1)
            | j > hi    = MV.read buf i >>= MV.write arr k >> mergeLoop (i+1) j (k+1)
            | otherwise = do
                vi <- MV.read buf i
                vj <- MV.read buf j
                if vi <= vj
                  then MV.write arr k vi >> mergeLoop (i+1) j (k+1)
                  else MV.write arr k vj >> mergeLoop i (j+1) (k+1)
      mergeLoop lo (mid + 1) lo

checksum :: MV.IOVector Word64 -> IO Word64
checksum arr = do
    let n = MV.length arr
        go !i !h
          | i >= n    = return h
          | otherwise = do
              x <- MV.read arr i
              go (i+1) (h * 131 + x)
    go 0 0

main :: IO ()
main = do
    args <- getArgs
    case args of
      [algo, ns] -> do
        let n = read ns :: Int
        arr <- generateArray n 42

        t0 <- getTime Monotonic
        case algo of
          "quick" -> quicksort arr 0 (n - 1)
          "merge" -> do
            buf <- MV.new n
            mergesortRec arr buf 0 (n - 1)
          _ -> error $ "Unknown algo: " ++ algo
        t1 <- getTime Monotonic

        let ms = fromIntegral (toNanoSecs t1 - toNanoSecs t0) / 1e6 :: Double
        cs <- checksum arr
        putStrLn $ algo ++ " n=" ++ show n ++ " " ++ show ms ++ "ms checksum=" ++ show cs
      _ -> putStrLn "Usage: sort <quick|merge> <n>"
