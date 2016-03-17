---
title: Why is SelectMany so weird?
series: Fun with Functional C#
part: III
---

This episode, we'll be looking at why `SelectMany` will look so strange to Haskell users, why that's linked to some implementation-level issues with C#, and the extremely cool way that the C# team got around those issues.

A quick recap: LINQ query syntax is actually just Haskell do-notation, specialized for the list monad.

We can see this by looking at the signature for `SelectMany`: 

```java
IEnumerable<B> SelectMany<A, B>(
  this IEnumerable<A> source,
  Func<A, IEnumerable<B>> selector
)
```

It's a less polymorphic Haskell bind:

```haskell
bind :: Monad m => m a -> (a -> m b) -> m b
```

When I first saw this, I immediately attempted to write my own monad instance in C#, and had a Bad Time. But figuring out why it wasn't so easy was probably more interesting than writing the monad instances in the first place!

<!--more-->

## Desugaring
With do-notation, if you write
```haskell
permutations :: [(Int, Char)]
permutations = do
  number <- [1,2,3]
  letter <- ['a','b','c']
  return (number, letter)
```

it will be desugared into

```haskell
permutations =
  [1,2,3] >>= \number ->
    ['a','b','c'] >>= \letter ->
      return (number, letter)
```
Because of the nested lambdas, the final `return` has all the bound variables[^bound] in scope, which is why do-notation has such an imperative flavor.

[^bound]: In this case, `number` and `letter`.

Here's the same thing in C#:

```java
from number in new List<int>{1,2,3}
from letter in new List<char>{'a','b','c'}
select $"({number}, {letter})";
```

If you're used to Haskell do-notation, you'd expect this to desugar nicely into:

```java
new List<int>{1,2,3}.SelectMany(number =>
  new List<char>{'a','b','c'}.Select(letter => 
    $"({number}, {letter})"
  )
);
```

But if you just try to run this code, and you've only implemented the `SelectMany` overload that corresponds with Haskell bind[^implemented], you'll get an error saying: `No overload for 'SelectMany' takes '3' arguments`.

[^implemented]: You wouldn't actually see this error for `IEnumerable`, since it's implemented by default. But you'll see the error if you implement your own monad instances.

This is a clue that the C# compiler is desugaring this into a call to a mysterious version of `SelectMany` that takes three arguments:

```java
IEnumerable<C> SelectMany<A,B,C>(
  this IEnumerable<A> source,
  Func<A, IEnumberable<B>> f,
  Func<A, B, C> projection
)
```

## Three arguments?
It turns out that no one wanted to write `SelectMany` like this; it was forced on the C# team because of an optimization issue with nested lambdas and method overloads[^overload]. Let's take a look at an example.

[^overload]: Haskell can desugar directly into nested `bind` calls because it doesn't support method overloading.

Here are the signatures of three overloaded methods:

```java
string A(Func<string, string> f);
DateTime A(Func<DateTime, DateTime> f);
string A(Func<DateTime, string> f);
```

If we write:

```java
A(x => x.AddMinutes(5));
```

It's pretty obvious that the type of `x` in the lambda should resolve to `DateTime`. But the compiler needs to check *all* the other overloads, even if it's already found one that typechecks, or it can't know that it's found a *unique* overload. Consider what happens if we write:

```java
A(x => x.ToString());
```

You'd expect the compiler to complain that the type of the lambda is ambiguous; it could be a `Func<string, string>` or a `Func<DateTime, string>`. So if we have \\(n\\) overloads, we need to check all \\(n\\) of them.

Unfortunately for the compiler, we can also write a nested lambda:

```java
A(x => A(y => x.AddMinutes(3).ToString() + y.ToString()));
```

Now, for each possible type of `x`, the compiler needs to check all possible types of `y`, to make sure there's a single, unambiguous overload resolution for this line of code. At this rate, we're going to need to check \\(n^m\\) possibilities, for \\(n\\) overloads and \\(m\\) levels of nesting[^sat]. If you had a method with ten overloads and nested it seven deep, the compiler would need to check ten million overloads, which would probably make Intellisense a little sluggish.

[^sat]: Amusingly, Eric Lippert, from whom I shamelessly [stole](http://ericlippert.com/2013/04/02/monads-part-twelve/) this section of the post, managed to [encode 3SAT into the overload resolution of nested lambdas](https://blogs.msdn.microsoft.com/ericlippert/2007/03/28/lambda-expressions-vs-anonymous-methods-part-five/), proving that this problem is at least NP-hard!

## The optimization

If you try to use multiple `from` statements in a LINQ query expression, it won't be desugared into a nested `SelectMany`, like you'd expect. Instead, the compiler will try to use that weird version of `SelectMany`, avoiding the nesting and its \\(n^m\\) behaviour:

```java
IEnumerable<C> SelectMany<A,B,C>(
  this IEnumerable<A> source,
  Func<A, IEnumberable<B>> f,
  Func<A, B, C> projection
)
```

So when you write:

```java
from number in new List<int>{1,2,3}
from letter in new List<char>{'a','b','c'}
select $"({number}, {letter})";
```

The final `select` statement of the query is desugared into a lambda:

```java
(number, letter) => $"({number}, {letter})"
```

This lambda has a type of `Func<int, char, string>`, which allows it to slot into the `Func<A,B,C>` parameter of `SelectMany`. Desugaring the rest of the query expression gives us some plain C#:

```java
new List<int>{1,2,3}.SelectMany(
  number => new List<char>{'a','b','c'},
  (number, letter) => $"({number}, {letter})"
);
```

Now we don't need nested lambdas to have both `number` and `letter` in scope!

## More where that came `from`
If you're paying attention, you'll have noticed something fishy- the signature for `SelectMany` only seems sensible if you only have two `from` statements. The final parameter to the three-argument overload of `SelectMany` has a type of `Func<A,B,C>`, which works fine if you only need to pass two variables to the final `select`. But if you have three `from` statements[^let], it doesn't seem like you can have all three variables in scope for the final projection, because a `Func<A,B,C>` only has two parameters.

[^let]: Or any query expression that binds more than two variables; you could have two `from`s and a `let`, for instance.

For instance, we should be able to bind three variables in a query expression like this:

```java
from number in new List<int>{1,2,3}
from letter in new List<char>{'a','b','c'}
from item in itemList
select $"({number}, {letter}, {item.Name})";
```

There's three variables we need in scope for the final `select`, but it's supposed to desugar into a `Func<A,B,C>`, which only has room for two variables! It seems like this version of `SelectMany` only manages to avoid one level of nesting; add another `from` statement and we're back to square one.

But the C# compiler has another trick up its sleeve, *transparent identifiers*, that was introduced to solve this very issue.

When the compiler encounters two `from`s followed by anything that's not a `select`, it rewrites them like we did earlier, and binds the result to a transparent identifier, represented by a `*`. The result is this intermediate query:

```java
from * in new List<int>{1,2,3}.SelectMany(
            number => new List<char>{'a','b','c'},
            (number, letter) => new { number, letter }
          )
from item in itemList
select $"({number}, {letter}, {item.Name})";
```

Now we're back at the two `from`s case, and we can rewrite again:

```java
new List<int>{1,2,3}
  .SelectMany(
      number => new List<char>{'a','b','c'},
      (number, letter) => new { number, letter }
  )
  .SelectMany(
      * => itemList,
      (*, item) => $"({number}, {letter}, {item.Name})"
  );
```

We've desugared this query without any nasty nesting! But what is that `*`?

## The * of the show
Depending on your sensibilities, you can look at transparent identifiers as a nasty hack or a brilliant workaround[^both]. Basically, they allow chained method calls to emulate the scoping behaviour of nested lambdas.

[^both]: Or both.

Let's zoom in:

```java
from * in new List<int>{1,2,3}.SelectMany(
            number => new List<char>{'a','b','c'},
            (number, letter) => new { number, letter }
          )
```

The `*` represents a transparent identifier, which has an anonymous type:

```java
* = new { number, letter }
```

Because we can't use nesting, we can't rely on lexical closure to get the `number` and `letter` variables in scope for the next `from`. So the compiler creates a transparent identifier with an anonymous type `{number, letter}`, effectively bundling the two types into one product type. And now we can call `SelectMany` on this anonymous type, and look inside it for our two variables.

Let's desugar it further.

```java
new List<int>{1,2,3}
  .SelectMany(
      number => new List<char>{'a','b','c'},
      (number, letter) => new { number, letter }
  )
  .SelectMany(
      transId => itemList,
      (transId, item) => $"({transId.number}, {transId.letter}, {item.Name})"
  );
```

That actually looks pretty normal! The `transId` variable contains our two previously bound variables, which, if you're keeping score, means we've managed to squeeze three variables into a function scope that only has two parameters, *without* using closures.

That's not all, though. This idea generalizes to arbitrary numbers of `from` or `let` statements, by giving transparent identifiers transitive scoping. Let's see how that works. This expression:

```java
from number in new List<int>{1,2,3}
from letter in new List<char>{'a','b','c'}
from item in itemList
from widget in widgetList
select $"({number}, {letter}, {item.Name}, {widget.Id})";
```

will desugar into an expression with multiple transparent identifiers:

```java
new List<int>{1,2,3}
  .SelectMany(
      number => new List<char>{'a','b','c'},
      (number, letter) => new { number, letter }
  )
  .SelectMany(
      *1 => itemList,
      (*1, item) => { *1, item }
  )
  .SelectMany(
      *2 => widget,
      (*2, widget) => $"({number}, {letter}, {item.Name}, {widget.Id})"
  );
```

The transitivity of transparent identifier scope is achieved by nesting transparent identifiers:

```java
*1 = { number, letter }
*2 = { *1, item }
```

It's interesting that we've exchanged one kind of nesting for another! Now we can resolve the nested transparent identifiers:

```java
new List<int>{1,2,3}
  .SelectMany(
      number => new List<char>{'a','b','c'},
      (number, letter) => new { number, letter }
  )
  .SelectMany(
      ti1 => itemList,
      (ti1, item) => { ti1, item }
  )
  .SelectMany(
      ti2 => widget,
      (ti2, widget) =>
        $"({ti2.ti1.number}, {ti2.ti1.letter}, {ti2.item.Name}, {widget.Id})"
  );
```

And we've got vanilla C# chained method calls emulating closures!
