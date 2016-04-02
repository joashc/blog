---
title: cryptodiner
link: https://github.com/joashc/cryptodiner
date: 2015-01-01
---

A Haskell implementation of Chaum's dining cryptographers protocol, using \\(Z_p^*\\) Diffie-Hellman, for cryptographically secure anonymous communication. Uses STM to manage concurrency, and the whole thing is structured with the free monad. It currently uses a star-shaped network topology; I'm thinking of using a DHT to make it truly decentralised.
