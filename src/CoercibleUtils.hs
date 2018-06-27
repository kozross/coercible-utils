{- |
Primarily pulled from the
package @[newtype-generics](http://hackage.haskell.org/package/newtype-generics)@,
and based on Conor McBride's Epigram work, but
generalised to work over anything `Coercible`.

>>> ala Sum foldMap [1,2,3,4 :: Int] :: Int
10

>>> ala Endo foldMap [(+1), (+2), (subtract 1), (*2) :: Int -> Int] (3 :: Int) :: Int
8

>>> under2 Min (<>) 2 (1 :: Int) :: Int
1

>>> over All not (All False) :: All
All {getAll = True)

Users might also find the GHC plugin @<https://github.com/mpickering/hashtag-coerce hashtag-coerce>@ useful in tandem with this library.
-}
module CoercibleUtils
  ( -- * Coercive composition
    -- $coercive-composition
    (#.), (.#)

    -- * The classic "newtype" combinators
  , op
  , ala, ala'
  , under, over
  , under2, over2
  , underF, overF
  ) where

import Data.Coerce (Coercible, coerce)

-- $coercive-composition
--
--   The problem, in a nutshell:
--
--   If @N@ is a newtype constructor, then @(N x)@ will always have the same
--   representation as @x@ (something similar applies for a newtype deconstructor).
--   However, if @f@ is a function,
--   
--   > N . f = \x -> N (f x)
--   
--   This looks almost the same as @f@, but the eta expansion lifts it – the lhs could
--   be @⊥@, but the rhs never is. This can lead to very inefficient code. Thus we
--   steal a technique from Shachaf and Edward Kmett and adapt it to the current
--   (rather clean) setting. Instead of using @(N . f)@, we use @(N '#.' f)@, which is
--   just
--   
--   > coerce f `asTypeOf` (N . f)
--   
--   That is, we just pretend that f has the right type, and thanks to the safety
--   of 'coerce', the type checker guarantees that nothing really goes wrong.
--
--   We still have to be a bit careful, though: remember that '#.' completely ignores the
--   value of its left operand.
--
--   For more background see <https://ghc.haskell.org/trac/ghc/ticket/7542 GHC Trac #7542>.

-- | Coercive left-composition.
infixr 9 #.
(#.) :: Coercible b c => (b -> c) -> (a -> b) -> a -> c
(#.) _ = coerce
{-# INLINE (#.) #-}

-- | Coercive right-composition.
infixr 9 .#
(.#) :: Coercible a b => (b -> c) -> (a -> b) -> a -> c
(.#) f _ = coerce f
{-# INLINE (.#) #-}

-- | The first parameter is /completely ignored/ on the value level,
--   meaning the only reason you pass in the constructor is to provide type
--   information.
--
-- >>> op Identity (Identity 3)
-- 3
op :: Coercible a b
   => (a -> b)
   -> b
   -> a
op = coerce
{-# INLINE op #-}

-- | The workhorse of the package. Given a "packer" and a \"higher order function\" (/hof/),
--   it handles the packing and unpacking, and just sends you back a regular old
--   function, with the type varying based on the /hof/ you passed.
--
--   The reason for the signature of the /hof/ is due to 'ala' not caring about structure.
--   To illustrate why this is important, consider this alternative implementation of 'under2':
--
--   > under2' :: (Coercible a b, Coercible a' b')
--   >        => (a -> b) -> (b -> b -> b') -> (a -> a -> a')
--   > under2' pa f o1 o2 = ala pa (\p -> uncurry f . bimap p p) (o1, o2)
--
--   Being handed the "packer", the /hof/ may apply it in any structure of its choosing –
--   in this case a tuple.
--
-- >>> ala Sum foldMap [1,2,3,4 :: Int] :: Int
-- 10
ala :: (Coercible a b, Coercible a' b')
    => (a -> b)
    -> ((a -> b) -> c -> b')
    -> c
    -> a'
ala pa hof = ala' pa hof id
{-# INLINE ala #-}

-- | The way it differs from the 'ala' function in this package,
--   is that it provides an extra hook into the \"packer\" passed to the hof.
-- 
--   However, this normally ends up being 'id', so 'ala' wraps this function and
--   passes 'id' as the final parameter by default.
--   If you want the convenience of being able to hook right into the /hof/,
--   you may use this function.
--
-- >>> ala' Sum foldMap length ["hello", "world"] :: Int
-- 10
--
-- >>> ala' First foldMap (readMaybe @Int) ["x", "42", "1"] :: Maybe Int
-- Just 42
ala' :: (Coercible a b, Coercible a' b')
     => (a -> b)
     -> ((d -> b) -> c -> b')
     -> (d -> a)
     -> c
     -> a'
ala' _ hof f = coerce #. hof (coerce f)
{-# INLINE ala' #-}

-- | A very simple operation involving running the function /under/ the "packer".
--
-- >>> under Product (stimes 3) (3 :: Int) :: Int
-- 27
under :: (Coercible a b, Coercible a' b')
      => (a -> b)
      -> (b -> b')
      -> a
      -> a'
under _ f = coerce f
{-# INLINE under #-}

-- | The opposite of 'under'. I.e., take a function which works on the
--   underlying "unpacked" types, and switch it to a function that works
--   on the "packer".
--
-- >>> over All not (All False) :: All
-- All {getAll = True}
over :: (Coercible a b, Coercible a' b')
     => (a -> b)
     -> (a -> a')
     -> b
     -> b'
over _ f = coerce f
{-# INLINE over #-}

-- | Lower a binary function to operate on the underlying values.
--
-- >>> under2 Any (<>) True False :: Bool
-- True
under2 :: (Coercible a b, Coercible a' b')
       => (a -> b)
       -> (b -> b -> b')
       -> a
       -> a
       -> a'
under2 _ f = coerce f
{-# INLINE under2 #-}

-- | The opposite of 'under2'.
over2 :: (Coercible a b, Coercible a' b')
      => (a -> b)
      -> (a -> a -> a')
      -> b
      -> b
      -> b'
over2 _ f = coerce f
{-# INLINE over2 #-}

-- | 'under' lifted into a 'Functor'.
underF :: (Coercible a b, Coercible a' b', Functor f, Functor g)
       => (a -> b)
       -> (f b -> g b')
       -> f a
       -> g a'
underF _ f = fmap coerce . f . fmap coerce
{-# INLINE underF #-}

-- | 'over' lifted into a 'Functor'.
overF :: (Coercible a b, Coercible a' b', Functor f, Functor g)
      => (a -> b)
      -> (f a -> g a')
      -> f b
      -> g b'
overF _ f = fmap coerce . f . fmap coerce
{-# INLINE overF #-}
