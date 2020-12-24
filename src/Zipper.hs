module Zipper where

import Prelude hiding (Left, Right, cycle)
import GHC.Base ( Alternative((<|>)) )
import Data.Functor ( (<&>) )
import Data.Maybe (fromMaybe)

data Tree a = Tree a [Tree a] deriving Show -- not empty

data Place a = Top
             | Brother (Zipper a) [Tree a] [Tree a] deriving Show

data Zipper a = Zipper (Tree a) (Place a) deriving Show

getElem :: Zipper a -> a
getElem (Zipper (Tree a _) _) = a

toZipper :: Tree a -> Zipper a
toZipper t = Zipper t Top

fromZipper :: Zipper a -> Tree a
fromZipper (Zipper t Top) = t
fromZipper (Zipper t (Brother z l r)) = undefined 

data Dir = Down | Up | Left | Right

goDown :: Zipper a -> Maybe (Zipper a)
goDown (Zipper (Tree _ []) _) = Nothing
goDown z@(Zipper (Tree _ (c : cs)) p) = Just $ Zipper c (Brother z [] cs)

goUp :: Zipper a -> Maybe (Zipper a)
goUp (Zipper _ Top) = Nothing
goUp (Zipper t (Brother father l r)) = Just father

goRight :: Zipper a -> Maybe (Zipper a)
goRight (Zipper t Top) = Nothing 
goRight (Zipper _ (Brother _ _ [])) = Nothing
goRight (Zipper t (Brother f l (r : rs))) = Just $ Zipper r (Brother f (t : l) rs)

goLeft :: Zipper a -> Maybe (Zipper a)
goLeft (Zipper t Top) = Nothing 
goLeft (Zipper _ (Brother _ [] _)) = Nothing
goLeft (Zipper t (Brother f (l : ls) r)) = Just $ Zipper l (Brother f ls (t : r))

-- Cycles through a tree in a zipper form, visiting some nodes few times
cycle :: Zipper a -> [Zipper a]
cycle zip = zip : nexts zip Down
    where 
        nexts zip Down = 
            let down = goDown zip <&> \x -> x : nexts x Right
                left = goLeft zip <&> \x -> x : nexts x Down
                up   = goUp zip   <&> \x -> x : nexts x Left 
            -- if can't go up, down, and left it means zip is Top with no children 
            in fromMaybe (repeat zip) (down <|> left <|> up)
        nexts zip Right =
            case goRight zip of
                Nothing -> nexts zip Down    -- we hit the end 
                Just x  -> x : nexts x Right -- go til we hit the end
        nexts zip Up =
            case goUp zip of
                Nothing -> nexts zip Down
                Just x  -> x : nexts x Left
        nexts zip Left =
            case goLeft zip of
                Nothing -> nexts zip Up 
                Just x  -> x : nexts x Down

fullCycle :: Tree a -> [Zipper a]
fullCycle t = z : takeWhile (not . isTop) zs
    where isTop z  = case z of Zipper _ Top -> True
                               _            -> False
          (z : zs) = cycle $ toZipper t
