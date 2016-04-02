---
title: ProcessBus
date: 2014-01-01
link: https://github.com/joashc/ProcessBus
---

This is an abstraction layer over [LanguageExt.Process](https://github.com/louthy/language-ext/) for declaratively specifying service bus messaging topologies. It was really an excuse to use LanguageExt and see how far you could take the functional style in C#- I actually began writing it in Haskell and then "translating" it to C#.

It only works with LanguageExt.Process, but I found that the Redis persistence was far too slow to be useful over multiple machines. I might break out the declarative messaging topology part and make it work with arbitrary transport layers.
