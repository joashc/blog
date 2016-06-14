---
title: How does HaxlSharp work?
---

I wrote a C# version of [Haxl](https://github.com/facebook/Haxl) called [HaxlSharp](https://github.com/joashc/HaxlSharp). The original Haxl paper by Marlow, et al. is brilliantly titled *[There is no Fork: an Abstraction for Efficient, Concurrent, and Concise Data Access](http://community.haskell.org/~simonmar/papers/haxl-icfp14.pdf)*, and provides a great overview of Haxl. This post will focus more on the *differences* between the original Haskell implementation and my C# implementation.

## What is `Fetch<>`?
In HaxlSharp, we use query syntax to combine functions that return `Fetch<>` objects. Let's say we have these three `Fetch<>` objects/ functions:

```cs
Fetch<string> a;
Fetch<int> b;
Func<string, Fetch<int>> c;
```

We can combine them like this: 

```cs
from x in a
from y in b
from z in c(a)
select y + z;
```

`Fetch<>` is actually a free monad that collects lambda expression trees instead of lambda functions.

It divides these expression trees into groups of expressions that can be written applicatively, using a version of the `ApplicativeDo` algorithm that was recently merged into GHC[^do].

[^do]: You can check out the proposal [here](https://ghc.haskell.org/trac/ghc/wiki/ApplicativeDo).

<!--more-->

### A brief aside on `ApplicativeDo`
If `ApplicativeDo` finds two monadic bind statements that can be expressed applicatively:

```haskell
{-# LANGUAGE ApplicativeDo #-}
a <- x
b <- y
```

it will rewrite them as:

```haskell
(a, b) <- (,) <$> x <*> y
```
Generalizing to more than two statements is trivial. For instance, in this expression:

```haskell
{-# LANGUAGE ApplicativeDo #-}
a <- x
b <- y
c <- z
d <- q a b c
e <- r a c d
-- etc
```

the first three statements can be rewritten applicatively:

```haskell
(a, b, c) <- (,,) <$> x <*> y <*> z
```

Because of tuple destructuring and nested lambdas, subsequent monadic binds will have `a`, `b`, and `c` in scope:

```haskell
(,,) <$> x <*> y <*> z >>=
  \(a, b, c) -> q a b c >>=
    \d -> r a c d
      \e -> --etc
```

Here's where things start to diverge from the Haskell version. C# doesn't have tuple destructuring, nor does it desugar query expressions into nested lambdas. Overload resolution on nested lambdas has an appalling asymptotic complexity, so the C# compiler desugars query expressions using *transparent identifiers*[^trans] that emulate the scoping behaviour of nested lambdas.

[^trans]: See *[Why is SelectMany so weird?](2016-03-17-select-many-weird.html#the-of-the-show)* for details on transparent identifiers.

Unfortunately, transparent identifiers are meant to be an internal compiler implementation detail, and aren't really accessible to us as library authors. If we want to mess around with the scoping behaviour of our lambda expressions- which we do if we want to rewrite them applicatively- we need to ditch transparent identifiers completely, and use our own scoping system.

### HaxlSharp scoping
In C#, we'd write that `ApplicativeDo` example like this:

```cs
from a in x
from b in y
from c in z
from d in q(a, b, c)
from e in r(a, c, d)
```

Let's say that these are all of type `Fetch<int>`. We will get four[^four] bind lambda expression trees:

[^four]: The initial lambda is simply `() => x`.

```cs
Expression<Func<int, Fetch<int>>>
bind1 = a => y;

Expression<Func<int, int, Fetch<int>>>
bind2 = (a, b) => z;

Expression<Func<TRANS0<int, int>, int, Fetch<int>>>
bind3 = (ti0, c) => q(ti0.a, ti0.b, c);

Expression<Func<TRANS1<TRANS0<int, int>, int>, int, Fetch<int>>>
bind4 = (ti1, d) => r(ti1.ti0.a, ti1.c, d);
```

We can't really manipulate transparent identifiers, so we rewrite all these expresions to take a `Scope` object, which is basically a `Dictionary<string, object>` that can spawn child scopes.

Here's the expressions rewritten as `Expression<Func<Scope, Fetch<int>>>`:

```cs
Expression<Func<Scope, Fetch<int>>>
bind1 = scope => y;

Expression<Func<Scope, Fetch<int>>>
bind2 = scope => z;

Expression<Func<Scope, Fetch<int>>>
bind3 = scope => 
  q((int)scope.Get("a"), (int)scope.Get("b"), (int)scope.Get("c"));

Expression<Func<Scope, Fetch<int>>>
bind4 = scope => 
  r((int)scope.Get("a"), (int)scope.Get("c"), (int)scope.Get("d"));
```

All transparent identifier and parameter accesses have been replaced with scope accessors.

If we have a nested `Fetch<>`:

```cs
var fetch1 = 
  from a in x
  from b in y
  from c in z
  select tuple(a, b, c);

var fetch2 = 
  from a in x
  from b in fetch1
  select tuple(a, b);
```

`fetch1` will be given a child scope, so it can access the parent variable `a` without polluting the scope of the parent.

### Fetching
All our expressions now assume every value they use is present in the scope. We ensure this by running applicative groups concurrently and awaiting their completion. Once the applicative group fetching is complete, we write the results to the scope with their respective variable names, and then pass this populated scope to the next applicative group, and so on.
