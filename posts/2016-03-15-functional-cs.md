---
title: Functional C#
series: Fun with Functional C#
part: I
---

With the introduction of LINQ in C#3, Erik Meijer and co. rebranded monads and presented them to a huge audience, and I think the way they did it was a brilliant piece of programming language UX design.

Apparently, before Erik Meijer joined the team working on LINQ, their goal was just to reduce the impedance mismatch between SQL databases and C#. So the solution they came up with was to let developers query SQL databases by writing SQL queries directly within C#- basically a language-level ORM.

I guess someone must have pointed out, wait a minute, there's also the same impedance mismatch when you're interacting with XML data- why are we limiting ourselves to relational databases?

And then Erik Meijer came along[^erik] and said, query comprehension can be represented as a monad, so we can do all these things, and make it work for in-memory objects too, and reactive streams, and any queryable we can think of!

[^erik]: I wasn't actually there, I just like to imagine this is what happened.

Now Pandora's Monad[^pandora] is open, the M-word is floating around the hallways and people are getting into heated discussions about the Yoneda Lemma and the co-Yoneda lemma. Your coworkers are saying, look at Haskell, these problems have been *solved* in a general way for years! 

[^pandora]: Not actually a thing.

It must have been tempting to just blindly retrofit functional concepts into C# and tell developers to just `fmap` and `fold` and `bind` to their heart's content. But they didn't, because immediately grasping the utility of these concepts is almost impossible at first glance, so they stuck a particular abstraction level and stuck with it. I guess a part of it could have been that C#'s type system can't actually represent monads, but to me it looked like a concious design decision to solve the problem at an appropriate level of abstraction.

<!--more-->

## LINQ is a Monad?

So C#3 brought LINQ, with its deliberately query-centric interface. But they also introduced extension methods, which allowed LINQ to be a bunch of generic extension methods on the `IEnumerable` interface. This also meant that you could implement SelectMany for your type:

```java
M<B> M<A, B>(this M<A> source, Func<A, M<B>> selector)
```

and you'd get query syntax for free! This is because `SelectMany` is actually just a special case of:

```haskell
bind :: Monad m => m a -> (a -> m b) -> m b
```

and query syntax is actually do-notation!

When I first discovered that LINQ was a monad, I was struck with a vision of a world without dependency injection runtime errors, and started writing the Reader monad in LINQ. After some wrangling with the type system, I found that while it *worked*, it was awkward, and not something I'd use in production.

## LanguageExt
A while later, I stumbled on [language-ext](https://github.com/louthy/language-ext), a library that attempts to coerce C# into behaving more like a functional language.

I wondered how it would feel to write Haskell in C#, so I set about using the features of language-ext to write a service bus layer over LanguageExt.Process, an Erlang-style concurrency system that's part of the language-ext project.

A lot of the most frustrating parts of C# had already been patched over with language-ext, but the results were still a mixed bag. Some elements of functional style didn't translate so well, others did:

## What didn't translate well
I thought that writing Haskellish code in C# wasn't actually that bad, but because I was essentially thinking in Haskell and then "translating" into C#, there were a lot of times something that was simple in Haskell required a great deal of ceremony and awkwardness[^pain].

[^pain]: I'm sure that contorting any language to do things it wasn't designed for is bound to be at least slightly painful.

My biggest sticking points with functional C# mainly revolved around the type system.

#### Type syntax
C#'s type syntax is rather cumbersome, making writing and reading type signatures a rather unpleasant experience. Much of what makes Haskell enjoyable is encoding as much information as possible into the types and letting the compiler do as much work for you as possible. C# actively works against you in this regard. It's amazing how opaque fairly basic type signatures look:

```java
IEnumerable<B> SelectMany<A, B>(this IEnumerable<A> source, Func<A, IEnumerable<B>> selector)
```

compared with their Haskell equivalent:

```haskell
selectMany :: Foldable t => t a -> (a -> t b) -> t b
```

I was always mentally translating C# signatures into their Haskell equivalent, which have a shape and "glancability" that the C# signatures lack. Functional programming involves a lot of gluing functions together, something that's hindered when you're mentally transposing the return type of the function to the other end.


#### Weak type inference
Compounding the issue is the weak type inference, forcing you to repeatedly write out type annotations:

```java
public static Either<IConfigError, RoutingDefinition> CheckDuplicateTransports(RoutingDefinition def)
{
  var hasDuplicates = CheckDuplicates(def);
  if (hasDuplicates) return Left<IConfigError, RoutingDefinition>(DuplicateTransports.Error);
  else return Right<IConfigError, RoutingDefinition>(def)
}
```

instead of just `Left(DuplicateTransports.Error)`. You can sort of hack around this by dumping a bunch of monomorphic functions into a static class:

```java
public static class EitherFunctions
{
  public static Func<RoutingDefintion, Either<IConfigError, RoutingDefinition>>
  RightDef = Right<IConfigError, RoutingDefinition>

  public static Func<IConfigError, Either<IConfigError, RoutingDefinition>>
  LeftDef = Left<IConfigError, RoutingDefinition>
}
```

but doing this is probably a sign that you're going down the wrong path.

#### Lack of higher-kinded types
Another is the lack of higher-kinded types, which prevents you from writing a `sequence` function that's polymorphic over all monad instances, for example. The lack of a well-understood, reusable toolkit for working with monads really detracts from their utility.

#### Null
This is valid C#:
```java
Option<Transport> something = null
```

#### Classes
Sometimes I'd want to write:

```haskell
data Transport = Transport {
  path :: String,
  forwards :: [Transport]
}
```

but creating immutable classes in C# requires you to write:

```java
public class Transport 
{
    public Transport(string Path, Lst<Transport> forwards)
    {
        Path = path;
        Forwards = forwards;
    }

    public string Path { get; }
    public Lst<Transport> Forwards { get; }
}
```

I know it's just sugar, but this kind of wears on you after a while.

## What did translate well?

There were quite a few times when I was pleasantly surprised at what cleanly translated into C#.

#### LINQ Query syntax
LINQ query syntax actually works quite well in C#. After you've implemented the right methods, query syntax is basically do-notation: 

Here's the reader monad:

```sql
from uri in GetUri()
from timeout in Ask(config => config.TimeoutSeconds)
select $"The absolute uri is '{uri.AbsoluteUri}' and the timeout is {timeout} seconds.";
```

You can (rather pointlessly) implement it for Tasks:

```sql
from bigData in getBigDataAsync()
from hadoop in spinUpHadoopInstanceAsync()
select hadoop.mapReduce(bigData)
```

### Either
I think the either monad works pretty well. 

One thing that I liked was the ability to define a function that returned an `Option` and convert it to an either:

```java
Option<Config> ParseConfig(string serialized);

// App1
ParseConfig(text).ToEither(App1Error);

// App2
ParseConfig(text).ToEither(App2Error);
```

This allows you to return a different error in different contexts, while still using the same function.

The either monad works well, allowing you to compose a bunch of functions that return errors into one big function that returns the correct error if any of those fail:

```sql
from forwardExists in CheckForwardsExist(config)
from definition in ConfigToDefinition(forwardExists)
from acyclic in CheckForwardingCyclicity(definition)
from nonDupe in CheckDuplicateTransports(acyclic)
from noSelfForwards in CheckSelfForwarding(nonDupe)
```

But query syntax here is unnecessary and error-prone. Luckily, you can just write:

```java
CheckForwardsExist(config)
    .Bind(ConfigToDefinition)
    .Bind(CheckForwardingCyclicity)
    .Bind(CheckDuplicateTransports)
    .Bind(CheckSelfForwarding);
```

which is actually something I'd use- it's self-contained, elegant, and really easy to refactor or add new validation.

###  Option
language-ext calls the maybe monad `Option`. C# has "nullables", but they don't compose. The ability to return an optional and thread it through a bunch of functions without worrying about null checks feels so much better than vanilla C#. I especially like `Find`:

```java
Option<int> firstPositive = list.Find(num => num > 0);
```

It's so much better than `FirstOrDefault`, and allows you to focus on writing the "happy path", while letting `Option` take care of missing values.

```sql
from firstPositive in list.Find(num => num > 0)
from firstNegative in list.Find(num => num < 0)
select firstPositive + firstNegative;
```

vs.

```java
// Can't do this, it'll return a 0.
// list.FirstOrDefault(num => num > 0) 

var positives = list.Where(num => num > 0);
var negatives = list.Where(num => num < 0);

if (!positives.Any() || !negatives.Any()) return null;

// We're evaluating each query twice here.
return positives.First() + negatives.First();
```

It's great.

### Static using
Strangely, this is my favorite feature[^interp] of C#6. Static classes and methods tend to be purer than their non-static counterparts. You can write:

[^interp]: Perhaps tied with string interpolation.

```java
using static StaticClass;
```

and then use the static methods of `StaticClass` by just writing `Foo` instead of `StaticClass.Foo`. I think this really encourages the use of pure functions. 

## How functional?
There's always an element of taste when it comes to using these features. There are some clear wins, like using `Find` instead of `FirstOrDefault`. Having an `Option` type propagate through a codebase might ring some alarm bells (as any far-reaching change should), but I think all it's doing is reifying something that used to be an implicit source of bugs. You can always pattern-match away the `Option`s if you want to expose a vanilla C# API.

There are some other features that I'm not so sure about, though. Using the reader monad instead of dependency injection, for example, requires a radical restructure of your entire application, and there's likely to be things you'll still need to use DI for. In fact, the next installment in this series will look at the reader monad in more detail.
