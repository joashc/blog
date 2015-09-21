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

Similarly, we can define another forgetful functor \\(\\it{A}: \\bf{Rng} \\rightarrow \\bf{Ab}\\), which maps from the category of rngs to the category of abelian groups. \\(\\it{A}\\) discards the multiplicative binary operation, but preserves all morphisms of multiplication in terms of morphisms of addition.


Forgetting monoids
------------------

The forgetful functor \\(\\it{A}\\) forgets ring multiplication. What happens if instead you forget addition? You get monoids!  We can define monoids as the triple \\((S, \\cdot, e)\\), where \\(S\\) is a set, \\(\\cdot\\) is an associative binary operation, and \\(e\\) is the neutral element of that operation.

The forgetful functor \\(\\it{M}: \\bf{Ring} \\rightarrow \\bf{Mon}\\) maps from the category of rings to the category of monoids, \\(\\bf{Mon}\\), in which the objects are monoids, and the morphisms are monoid homomorphisms.

Monoid homomorphisms map between monoids in a way that preserves their monoidal properties. Given \\(\\mathcal{X}\\), a monoid defined by \\((X, \*, e)\\), and \\(\\mathcal{Y}\\), a monoid defined by \\((Y, \*', f)\\), a function \\(\\it{\\phi}: \\mathcal{X} \\rightarrow \\mathcal{Y}\\) from \\(\\mathcal{X}\\) to \\(\\mathcal{Y}\\) is a monoid homomorphism iff:

it preserves compositionality[^4]:
$$\begin{equation}\phi(a * b) = \phi(a) *' \phi(b), \forall a\; b \in \mathcal{X}\end{equation}$$

[^4]: All homomorphisms have one constraint in common: they must preserve compositionality. We can be generalise the homomorphism constraint for any \\(n\\)-ary operation; a function \\(\\it{f}: A \\rightarrow B\\) is a homomorphism between two algebraic structures of the same type if:
$$\it{f}(\mu_{A}(a_{1}, \ldots, a_{n})) = \mu_{B}(f(a_{1}), \ldots, f(a_n))$$
for all \\(a_{1}, \\ldots, a_{n} \\in A\\)

and maps the identity element:
$$\begin{equation}\phi(e) = f\end{equation}$$

Translating into Haskell, if `phi` is a monoid homomorphism between monoid `X` to monoid `Y`, then:

```haskell
phi (mappend a b) == mappend (phi a) (phi b)  -- (1)

phi (mempty :: X) == mempty :: Y              -- (2)
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

-- (1)
homomorphism :: [()] -> [()] -> Bool
homomorphism a b =
  phi (mappend a b) == mappend (phi a) (phi b)
    where phi = listToSum

quickCheck homomorphism
-- > OK, passed 100 tests.

-- (2)
listToSum (mempty :: [a]) == mempty :: Sum Int
-- > True

```

Let's forget some more things with yet another forgetful functor, \\(\\it{U}: \\bf{Mon} \\rightarrow \\bf{Set}\\)[^5].

[^5]: Technically, in Haskell we'd be mapping to the category \\(\\bf{Hask}\\), the category of Haskell types and functions.

\\(\\bf{Set}\\) is a category where the objects are sets, and the arrows are just plain functions. So \\(\\it{U}\\) will map every monoid in \\(\\bf{Mon}\\) to its underlying set, and every monoid homomorphism to a plain function.

`Sum Int` would just become `Int`, `listToSum` would just become `length`, `mappend :: Sum a` would map to `(+)`, and so on. We forget that any of these things were ever part of a monoid.

Natural Transformation
----------------------



Left Adjoint
------------

An adjuction \\(\\it{F} \\;\\vdash \\it{G}\\) between functors \\(\\it{F}: \\mathcal{D} \\rightarrow \\mathcal{C}\\) and \\(\\it{G}: \\mathcal{C} \\rightarrow \\mathcal{D}\\) means that 



What do you get for free?
-------------------------

This means that *any* functor can form a free monad. The free monad is initial, in the sense that there's a homomorphism to any 

A free functor \\(F\\) is left adjoint to a "forgetful" functor U, which we write as \\(F \\dashv U\\).

