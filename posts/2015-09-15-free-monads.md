---
title: Free monads
---

Forgetting how to multiply
--------------------------

It's probably easiest to understand what a free monad is if we first understand *forgetful functors*[^1].

[^1]: As far as I know, there's no formal way of describing the "forgetfulness" of a functor.

In category theory, a functor maps between categories, mapping objects to objects and morphisms to morphisms[^2].

[^2]:Crucially, functors must preserve compositionality, so that if two morphisms of the input category compose to form a third morphism, the image of those two morphisms under the functor must also compose to form the image of the third morphism.

A *forgetful functor* is just a functor that discards some of the structure or properties of the input category.

For example, unital rings have objects \\((R, +, \\cdot, 0, 1)\\), where \\(R\\) is a set, and \\((+, \\cdot)\\) are binary operations with identity elements \\((0, 1)\\) respectively.

Let's denote the category of all unital rings and their homomorphisms by \\(\\bf{Ring}\\), and the category of all non-unital rings and their homomorphisms with \\(\\bf{Rng}\\). We can now define a forgetful functor: \\(\\it{I}: \\bf{Ring} \\rightarrow \\bf{Rng}\\), which just drops the multiplicative identity.

We can also define \\(\\it{J}: \\bf{Rng} \\rightarrow \\bf{Ring}\\), which simply adds the multiplicative identity. \\(\\it{J}\\) is *left adjoint* to \\(I\\)[^3], which we denote \\(\\it{J} \\dashv \\it{I}\\).

[^3]: In this case, \\(\\it{I}\\) is also the inverse of \\(\\it{J}\\), but this is usually not the case.

Similarly, we can define a forgetful functor \\(\\it{A}: \\bf{Rng} \\rightarrow \\bf{Ab}\\), which maps from the category of rngs to the category of abelian groups. \\(\\it{A}\\) discards the multiplicative binary operation, but preserves all morphisms of multiplication in terms of morphisms of addition.


Forgetting monoids
------------------

The forgetful functor \\(\\it{A}\\) forgets ring multiplication. What happens if instead you forget addition? You get monoids!  Monoids have objects \\((M, \\cdot, e)\\), where \\(M\\) is a set, \\(\\cdot\\) is an associative binary operation, and \\(e\\) is the neutral element of that operation.

The forgetful functor \\(\\it{M}: \\bf{Ring} \\rightarrow \\bf{Mon}\\) maps to the category of monoids, \\(\\bf{Mon}\\), in which the objects are monoids, and the morphisms are monoid homomorphisms.

Monoid homomorphisms map between monoids in a way that preserves their monoidal properties. Given \\(M\\), a monoid defined by \\((m, \*, e)\\), and \\(N\\), a monoid defined by \\((n, \*', f)\\), a function \\(\\it{\\phi}: M \\rightarrow N\\) from \\(M\\) to \\(N\\) is a monad homomorphism iff: 

$$\begin{equation}\phi(e) = f\end{equation}$$
$$\begin{equation}\phi(a * b) = \phi(a) *' \phi(b), \forall a\; b \in N\end{equation}$$
Translating into Haskell, if `phi` is a monoid homomorphism between monoid `M` to monoid `N`, then:

```haskell
phi (mempty :: M) == mempty :: N

phi (mappend a b) == mappend (phi a) (phi b)
```

For example, we can define a monoid homomorphism that maps from the list monoid to the `Sum` monoid, the monoid formed from the natural numbers under addition:

```haskell
import Data.Monoid

listToSum :: [a] -> Sum Int
listToSum = Sum . length
```

We can quickly check if `listToSum` is actually a monoid homomorphism:

```haskell
import Test.QuickCheck

listToSum (mempty :: [a]) == mempty :: Sum Int
-- True

homomorphism :: [()] -> [()] -> Bool
homomorphism a b = 
  phi (mappend a b) == mappend (phi a) (phi b)
    where phi = listToSum

quickCheck homomorphism
-- OK, passed 100 tests.
```

Let's forget some more things with the forgetful functor \\(\\it{U}: \\bf{Mon} \\rightarrow \\bf{Set}\\)[^4].

\\(\\bf{Set}\\) is a category where the objects are sets, and the arrows are just plain functions. So \\(\\it{U}\\) will map every monoid in \\(\\bf{Mon}\\) to its underlying set, and every monoid homomorphism to a plain function.

[^4]: Technically, in Haskell we'd be mapping to the category \\(\\bf{Hask}\\), the category of Haskell types and functions.

`Sum Int` would just become `Int`, `listToSum` would just become `length`, `mappend :: Sum a` would map to `(+)`, and so on. We forget that any of these things were ever part of a monoid.


What do you get for free?
-------------------------

This means that *any* functor can form a free monad. The free monad is initial, in the sense that there's a homomorphism to any 

A free functor \\(F\\) is left adjoint to a "forgetful" functor U, which we write as \\(F \\dashv U\\).

