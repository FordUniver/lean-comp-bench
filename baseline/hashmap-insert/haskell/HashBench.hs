{-# LANGUAGE BangPatterns #-}
-- Reproducing lacker/lean4perf benchmark in Haskell
-- 10M string->int insertions into a hash map

module Main where

import qualified Data.HashMap.Strict as HM
import System.Clock (getTime, Clock(Monotonic), toNanoSecs)

main :: IO ()
main = do
    t0 <- getTime Monotonic

    let !m = go 0 HM.empty
    let !sz = HM.size m

    t1 <- getTime Monotonic
    let ms = fromIntegral (toNanoSecs t1 - toNanoSecs t0) / 1e6 :: Double
    putStrLn $ "ran " ++ show sz ++ " map inserts in " ++ show ms ++ "ms"
  where
    go :: Int -> HM.HashMap String Int -> HM.HashMap String Int
    go !i !m
      | i >= 10000000 = m
      | otherwise     = go (i + 1) (HM.insert (show i) i m)
