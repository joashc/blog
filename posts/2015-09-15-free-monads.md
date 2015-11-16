---
title: Free monads in category theory
series: Free monads
part: II
---

Forgetting how to multiply
--------------------------

It's probably easiest to understand what a free monad is if we first understand forgetful functors[^forget].

[^forget]: As far as I understand, there's no formal way of describing the "forgetfulness" of a functor.

In category theory, a functor maps between categories, mapping objects to objects and morphisms to morphisms in a way that preserves compositionality[^comp].

[^comp]: A functor "preserves compositionality" if two morphisms of the input category compose to form a third morphism, such that the image of those two morphisms under the functor also compose to form the image of the third morphism.

A *forgetful functor* is just a functor that discards some of the structure or properties of the input category.

For example, unital rings have objects \\((R, +, \\cdot, 0, 1)\\), where \\(R\\) is a set, and \\((+, \\cdot)\\) are binary operations with identity elements \\((0, 1)\\) respectively.

Let's denote the category of all unital rings and their homomorphisms by \\(\\bf{Ring}\\), and the category of all non-unital rings and their homomorphisms with \\(\\bf{Rng}\\). We can now define a forgetful functor: \\(\\it{I}: \\bf{Ring} \\rightarrow \\bf{Rng}\\), which just drops the multiplicative identity.

Similarly, we can define another forgetful functor \\(\\it{A}: \\bf{Rng} \\rightarrow \\bf{Ab}\\), which maps from the category of rngs to the category of abelian groups. \\(\\it{A}\\) discards the multiplicative binary operation, simply mapping all morphisms of multiplication to morphisms of addition.



Forgetting monoids
------------------

The forgetful functor \\(\\it{A}\\) forgets ring multiplication. What happens if instead you forget addition? You get monoids!  We can define monoids as the triple \\((S, \\cdot, e)\\), where \\(S\\) is a set, \\(\\cdot\\) is an associative binary operation, and \\(e\\) is the neutral element of that operation.

The forgetful functor \\(\\it{M}: \\bf{Ring} \\rightarrow \\bf{Mon}\\) maps from the category of rings to the category of monoids, \\(\\bf{Mon}\\), in which the objects are monoids, and the morphisms are monoid homomorphisms.

Monoid homomorphisms map between monoids in a way that preserves their monoidal properties. Given \\(\\mathcal{X}\\), a monoid defined by \\((X, \*, e)\\), and \\(\\mathcal{Y}\\), a monoid defined by \\((Y, \*', f)\\), a function \\(\\it{\\phi}: \\mathcal{X} \\rightarrow \\mathcal{Y}\\) from \\(\\mathcal{X}\\) to \\(\\mathcal{Y}\\) is a monoid homomorphism iff:

it preserves compositionality[^homo]:

$$\begin{equation}\phi(a * b) = \phi(a) *' \phi(b), \forall a\; b \in \mathcal{X}\end{equation}$$

[^homo]: All homomorphisms have one constraint in common: they must preserve compositionality. We can be generalise the homomorphism constraint for any \\(n\\)-ary operation; a function \\(\\it{f}: A \\rightarrow B\\) is a homomorphism between two algebraic structures of the same type if:
$$\it{f}(\mu_{A}(a_{1}, \ldots, a_{n})) = \mu_{B}(f(a_{1}), \ldots, f(a_n))$$
for all \\(a_{1}, \\ldots, a_{n} \\in A\\)

and maps the identity element:
$$\begin{equation}\phi(e) = f\end{equation}$$

<!--more-->

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

If it's too difficult (or we can't be bothered) to derive a formal proof, we can use [QuickCheck](https://hackage.haskell.org/package/QuickCheck) to test properties of functions. Let's quickly check if `listToSum` is actually a monoid homomorphism:

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

Let's forget some more things with yet another forgetful functor, \\(\\it{U}: \\bf{Mon} \\rightarrow \\bf{Set}\\)[^hask].

[^hask]: Technically, in Haskell we'd be mapping to the category \\(\\bf{Hask}\\), the category of Haskell types.

\\(\\bf{Set}\\) is a category where the objects are sets, and the arrows are just plain functions. So \\(\\it{U}\\) will map every monoid in \\(\\bf{Mon}\\) to its underlying set, and every monoid homomorphism to a plain function.

`Sum Int` would just become `Int`, `listToSum` would just become `length`, `mappend :: Sum a` would map to `(+)`, and so on. We forget that any of these things formed a monoid.

Natural Transformations
----------------------

Moving our discussion from forgetful functors to free constructions requires the concept of natural transformations. Recall that a functor \\(F: \\cal{C} \\rightarrow \\cal{D}\\) must take all objects \\(X \\in \\cal{C}\\) to \\(F(X) \\in \\cal{D}\\), and all morphisms \\(f: X \\rightarrow Y \\in \\cal{C}\\) to \\(F(f): F(X) \\rightarrow F(Y) \\in \\cal{D}\\), such that the following diagram commutes:

$$\require{AMScd} \begin{CD} X @>{f}>> Y\\ @V{F}VV @VV{F}V \\ F(X) @>{F(f)}>> F(Y)\end{CD}$$

This diagram says that it doesn't matter if we start with \\(X\\), apply \\(F\\) and then \\(F(f)\\), or start with \\(X\\) and instead apply \\(f\\) and then \\(F\\)- we always end up with \\(F(Y)\\). The functor has mapped between categories in a way that preserves the internal structure of the original category. 

A *natural transformation* is a similar sort of structure-preserving[^func] mapping, except instead of mapping between categories, it maps between functors.

[^func]: It's actually exactly the same kind of structure preservation, because functors form a category where the objects are functors and the morphisms are natural transformations.

Given functors \\(F, G: \\cal{C} \\rightarrow \\cal{D}\\), a natural transformation \\(\\eta\\) is a morphism between functors such that:

1. For all \\(X \\in \\mathcal{C}\\), there exists a morphism, \\(\\eta_{X}: F(X) \\rightarrow G(X)\\), where \\(F(X), F(G) \\in \\mathcal{D}\\)[^component]

2. For every morphism \\(f: X \\rightarrow Y \\in \\mathcal{C}\\), the following diagram- a *naturality square*- commutes:

[^component]: We call \\(\\eta_{X}\\) "the component of \\(\\eta\\) at \\(X\\)"

$$\require{AMScd} \begin{CD} F(X) @>{F(f)}>> F(Y)\\ @V{\eta_{X}}VV @VV{\eta_{Y}}V \\ G(X) @>{G(f)}>> G(Y)\end{CD}$$

This means we're making a rather strong claim about the properties of \\(\\eta\\): \\(G(f) \\circ \\eta\\) is the same as \\(\\eta \\circ F(f)\\)!

Adjunctions
-----------
Let's consider two functors going in opposite directions, \\(\\it{F}: \\mathcal{C} \\rightarrow \\mathcal{D}\\) and \\(\\it{G}: \\mathcal{D} \\rightarrow \\mathcal{C}\\).

\\(F\\) and \\(G\\) aren't just any old functors though- they're equipped with a *natural isomorphism*:

$$\alpha: \cal{D}\textrm{(}\it{FX, Y}\textrm{)} \cong \cal{C}\textrm{(}\it{X, GY}\textrm{)}$$

where the isomorphism is natural in \\(X\\) and \\(Y\\).

Simply saying these hom-sets are naturally isomorphic is rather imprecise. We can pin down the naturality of \\(\\alpha\\) by saying that certain natural transformations hold. But to define a natural transformation we need to define some functors!

We can define a natural transformation between these hom-functors from \\(X \\in \\mathcal{C}\\) to \\(Y \\in \\cal{D}\\), fixing \\(Y\\):

$$\cal{D}\textrm{(}\it{F\_, Y}\textrm{)}$$

$$\cal{D}\textrm{(}\it{\_, GY}\textrm{)}$$

We can use another notation to make their functorish nature more apparent:

$$X \mapsto \textrm{hom}(FX, Y): \cal{C}^{op} \rightarrow \bf{Set}$$

$$X \mapsto \textrm{hom}(X, GY): \cal{C}^{op} \rightarrow \bf{Set}$$

These functors take every object \\(X \\in \\mathcal{C}^{op}\\) to a hom-set of morphisms in \\(\\cal{D}\\), so it's perfectly valid to ask for a natural transformation between them:

$$\require{AMScd} \begin{CD} \cal{D}\textrm{(}\it{FX^{\prime},Y}\textrm{)}@>{\alpha}>> \cal{C}\textrm{(}\it{X^{\prime}, GY}\textrm{)} \\ @V{\_ \circ Ff}VV @VV{\_ \circ f}V \\ \cal{D}\textrm{(}\it{FX,Y}\textrm{)} @>{\alpha}>> \cal{C}\textrm{(}\it{X, GY}\textrm{)} \end{CD}$$

So for every morphism \\(f: X^{\\prime} \\rightarrow X \\in \\cal{C}\\), applying \\(\\alpha\\) and then precomposing with \\(f\\) is the same as precomposing with \\(Ff\\) and then applying \\(\\alpha\\). That's naturality in \\(X\\). Naturality in \\(Y\\) is much the same, except we fix \\(X\\), and get functors from \\(\\cal{D} \\rightarrow \\bf{Set}\\):

$$\require{AMScd} \begin{CD} \cal{D}\textrm{(}\it{FX,Y}\textrm{)}@>{\alpha}>> \cal{C}\textrm{(}\it{X, GY}\textrm{)} \\ @V{g \circ \_}VV @VV{Gg \circ \_}V \\ \cal{D}\textrm{(}\it{FX,Y^{\prime}}\textrm{)} @>{\alpha}>> \cal{C}\textrm{(}\it{X, GY^{\prime}}\textrm{)} \end{CD}$$

for all mophisms \\(g: Y \\rightarrow Y^{\\prime} \\in \\cal{D}\\).

We can think of \\(\\alpha\\) as a pair of hom-functors[^rich] that take \\(\\mathcal{C}^{op} \\rightarrow \\bf{Set}\\), and a pair of functors that take \\(\\cal{D} \\rightarrow \\bf{Set}\\), such that each pair of functors creates a bijection between their corresponding sets, satisfying the above naturality conditions.

[^rich]: Category theory brings a great richness of perspectives, allowing us to think about relationships in whatever way that happen to suit whatever we're trying to talk about.

We describe this functorial relationship by saying that \\(F\\) is *left adjoint* to \\(G\\), or \\(F \\dashv G\\).


Free monoids
------------

Armed with the ability to talk about the "adjointness" of functors, we can now examine what happens when we take \\(U\\) to be a forgetful functor, when \\(F \\dashv U\\).

If \\(U\\) is a forgetful functor that discards some information about its domain, \\(F\\) must be able to "reconstruct" enough to go from \\(D\\) to \\(C\\). The left adjoint to a forgetful functor is always a free functor!

Returning to our monoid example, if we take \\(U\\) to be \\(U: \\bf{Mon} \\rightarrow \\bf{Set}\\), the left adjoint to \\(U\\) is the free functor \\(F: \\bf{Set} \\rightarrow \\bf{Mon}\\).

This means there must be a natural isomorphism, \\(\\alpha\\), that creates a bijection between hom-sets of \\(F\\) and \\(U\\), such that all functions \\(a \\in \\bf{Set}\\) to an underlying set of \\(\\bf{Mon}\\) uniquely determines a monoid homomorphism that's natural in \\(a\\) and \\(b\\):

$$\alpha: \bf{Mon}\textrm{(}\it{Fa} \rightarrow b) \cong \bf{Set}\textrm{(}\it{a} \rightarrow \it{Ub}\textrm{)}$$

and vice-versa.

How could we construct \\(F\\) so that the above conditions are met? Spoiler alert: we can just use List! Let's try to translate \\(\\alpha\\), and its inverse, into pseudo-Haskell[^poly].

[^poly]: I'm not sure of a way to write a polymorphic function that "forgets" a monoid constraint, so we'll just wave our hands a bit until we get to Real Haskell.

```haskell
-- Just delete the monoid constraint
u :: Monoid m = m

alpha :: (List a -> Monoid m) = (a -> u (Monoid m))

alpha' :: (a -> u (Monoid m)) -> (List a -> Monoid m)
```

Now we can translate this into actual Haskell[^real]. Since `u` just removes the monoid constraint, we can substitute all instances of `u (Monoid m)` with simply `m`, and we can use the real list constructor and type constraint syntax:

```haskell
import Data.Monoid

alpha :: Monoid m => (a -> m) -> ([a] -> m)
alpha g xs = mconcat $ map g xs

alpha' :: Monoid m => ([a] -> m) -> (a -> m)
alpha' h x = h [x]
```

[^real]: This might look a bit strange- even though we've supposedly "forgotten" that `m` is a monoid in `alpha'`, the type variable `m` is still bound by the monoid type constraint. We can cheat, though, and explicitly parameterize a forgetful function `Monoid m => m -> b`:
    ```haskell
    alpha Monoid m=>(b->m)->(a->b)->([a]->m)
    alpha m g xs = mconcat $ map (m . g) xs

    alpha' Monoid m=>(m->b)->([a]->m)->(a->b)
    alpha' m h x = m . h $ [x]
    ```

To prove that `alpha` actually forms a natural isomorphism, we need to show that `alpha . alpha' = id`:

```haskell
-- Proof that alpha . alpha' = id

alpha . alpha'
-- eta expand
= \h x -> alpha (alpha' h) x

-- substitute definition of alpha'
= \h x -> alpha h [x]

-- substitute definition of alpha
= \h x -> mconcat (map h [x])

-- map f [x] = [f x]
= \h x -> mconcat ([h x])

-- mconcat [x] = x
= \h x -> h x

-- eta-reduce
= \h = h

-- definition of id
= id
```

and in the other direction, that `alpha' . alpha =  id`:

```haskell
-- Proof that alpha' . alpha = id

alpha' . alpha
-- eta-expand
= \g xs -> alpha' (alpha g) xs

-- substitute definition of alpha
= \g xs -> mconcat (map (alpha g) xs)

-- eta-expand
= \g xs -> mconcat (map (\x -> alpha g x) xs)

-- substitute definition of alpha'
= \g xs -> mconcat (map (\x -> g [x]) xs)

-- map (f . g) = map f . map g
= \g xs -> mconcat (map g (map (\x -> [x]) xs))

-- free theorem
= \g xs -> g (mconcat (map (\x -> [x]) xs))

-- mconcat [[a],[b],[c]] = [a,b,c]
= \g xs -> g xs

-- eta-reduce
= \g -> g

-- definition of id
= id
```

So it follows that the list does indeed form a free monoid! Interestingly, what we've already defined as `alpha` is just `foldMap`:

```haskell
alpha :: Monoid m => (a -> m) -> ([a] -> m)

foldMap :: Monoid m => (a -> m) -> [a] -> m
```

So in more Haskellish terms, we map each element of a list to a monoid, and then combine the results using the structure of that monoid.

```haskell
foldMap Product [2,4,6]
-- Sum {getSum = 12}

foldMap Product [2,4,6]
-- Product {getProduct = 48}
```

Of course, `foldMap` is really defining a monoid homomorphism:

```haskell
-- Monoid homomorphisms map the identity element
foldMap Product []
-- Product {getProduct = 1}

foldMap Sum []
-- Product {getSum = 0}

-- ...and preserve compositionality
homomorphism :: [Int] -> [Int] -> Bool
homomorphism a b = phi (a ++ b) == phi a `mappend` phi b
  where phi = foldMap Sum

quickCheck homomorphism
-- OK, passed 100 tests.
```

Free Monads
----------

Now let's take a look at free monads. Of course, monads are just monoids in the category of endofunctors, so we can apply what we've already learned! A monad is an endofunctor \\(T: \\cal{C} \\rightarrow \\cal{C}\\) equipped with natural transformations \\(\\eta: 1_{\\cal{C}} \\Rightarrow T\\) and \\(\\mu: T^{2} \\Rightarrow T\\), obeying the obvious[^obvious] axioms of identity and associativity. The \\(\\bf{Monad}\\) category has monads as objects, and monad homomorphisms as arrows.

[^obvious]: Obvious to experienced category theorists, at least.

We can define a forgetful functor, \\(U: \\bf{Monad} \\rightarrow \\bf{End}\\), that maps from the category of monads to the category of endofunctors. The category of endofunctors, \\(\\bf{End}\\), has endofunctors as objects and natural transformations as arrows, so \\(U\\) should be a forgetful functor such that:

- For every monad \\(T\\), \\(U\\) will forget \\(\\eta\\) and \\(\\mu\\), and just give us the underlying endofunctor \\(T\\).
- For every monad homomorphism \\(\\phi\\), \\(U\\) will give us a natural transformation in \\(\\bf{End}\\).

Now we can see what behaviour \\(F\\) should have, when \\(F \\vdash U\\):

- For every endofunctor \\(A\\), \\(F A\\) should be a monad.
- For every natural transformation \\(\\eta: A \\Rightarrow B\\), \\(F \\eta\\) should be a monad homomorphism.
- The isomorphism \\(F A \\Rightarrow B \\cong A \\Rightarrow U B\\) should be natural in \\(A\\) and \\(B\\).

Again, this makes very strong claims about the behaviour of \\(F\\). It turns out that the following construction[^asym] satisfies all these criteria:

We're effectively asking for the existence of 

[^asym]: The way this construction defines the bind operator results in a quadratic asymtotic complexity. Janis Voigtlander describes an approach for reducing the asymtotic complexity to linear in his paper *[Asymtotic Improvement of Computations over Free Monads](http://www.janis-voigtlaender.eu/papers/AsymptoticImprovementOfComputationsOverFreeMonads.pdf)*.

```haskell
data Free f a = Pure a | Free (f (Free f a))

instance Functor f => Monad (Free f) where
  return a = Pure a
  Pure a >>= f = f a
  Free m >>= f = Free (fmap (>>= f) m)
```

The monadic bind operation `(>>=)` can be defined in terms of "substitution followed by renormalization":

```haskell
Monad m => m a -> (a -> m b) -> m b
m >>= f = join (fmap f m)
```

In conventional monads, we substitute the `a` in our monad `m a` with `m b`, to get `m m b`, and then we renormalize with \\(\\mu: T^{2} \\Rightarrow T\\) (which we call `join` in Haskell) to get `m b`. Free monads still perform the substitution of the underlying functor, but because `Free` type is defined recursively as `Free (f (Free f a))`, we effectively get \\(\\mu: T^2 \\Rightarrow T\\) for free by by sticking another layer of `Free` on top. It's a lossless process; everything you've joined is retained[^join]. In fact, `Free` looks suspiciously like `List`:

```haskell
data List a = Nil | Cons (List a)

data Free f a = Pure a | Free (f (Free f a))
```

[^join]: This gives an intuition for why any natural transformation between endofunctors, \\(f: A \\Rightarrow UB\\), can be fed to the free functor to form a monad homomorphism, \\(Ff: FA \\Rightarrow B\\). Just like the free monoid, we don't "throw away" any information about the free construction beyond what's defined by the underlying category.

So `Free` is basically just a list of functors! When we defined the free monoid, the natural isomorphism constraint basically forced us into defining `foldMap`, which mapped each element of the list to a monoid, and then used the structure of that monoid to join the resulting elements:

```haskell
foldMap :: Monoid m => (a -> m) -> [a] -> m
foldMap f xs = mconcat $ map f xs
```

Now we're going to do the same for the free monad, by defining the natural transformation `foldFree`, and its inverse, `foldFree'`:

```haskell
foldFree :: (Functor f, Monad m) =>
  (forall a . f a -> m a) -> Free f a -> m a
foldFree' :: (Functor f, Monad m) => 
  (forall a . Free f a -> m a) -> f a -> m a
```

Doing that is as simple as following the types:

```haskell
foldFree _ (Pure x) = return x
foldFree phi (Free xs) = join $ phi $ fmap (foldFree phi) xs

foldFree' psi = psi . Free . (fmap Return)
```

Proving that `foldFree . foldFree' = id` is left as an exercise for the reader.
