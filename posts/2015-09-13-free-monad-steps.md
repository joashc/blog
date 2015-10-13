---
title: Free monads in 7 easy steps
series: Free monads
part: I
---

In [the next part](/posts/2016-01-24-free-monad-theory.html) of this series, we'll discuss free monads from a category theory perspective. This first installment will be decidedly more practical, focusing on how you actually *use* free monads in Haskell, and what advantages they bring. This means I'll gloss over a lot of the mechanics of how free monads actually *work*, and make this more of a "get it done" kind of post.

## The finest imperative language?
Simon Peyton-Jones famously said that Haskell was the world's finest imperative programming language. When I started writing Haskell, however, I literally tacked `-> IO ()` onto the end of all my functions and went to town writing imperative code.

Of course, not *all* the functions I wrote returned an `IO ()`, but because that was the only tool that I had to interact with the outside world, a great deal of my code- far more than necessary- simply lived inside the IO monad.

Here's a pretty representative example, from a program I wrote that implemented anonymized network chat[^chaum]:

[^chaum]: Using a very dodgy, hand-rolled version of Chuam's dining cryptographers protocol. 

```haskell
keyExchangeHandler :: Either String PeerData -> MVar ServerState -> IpAddress -> Int -> Handle -> IO ()
keyExchangeHandler p state ip portNumber handle = case p of
  Right peerData -> do
    s <- takeMVar state
    let peer = Participant (publicKey peerData) (nonce peerData) ip portNumber
    let newPs = peer:(peers s)
    if length newPs == groupSize s
       then forkIO $ sendPeerList state
       else forkIO $ putStrLn "Waiting for peers"
    putMVar state s{ peers = newPs }
  Left e -> putStrLn $ "Could not parse public key: " ++ e
```

The semantics of the application logic are completely mixed up with implementation-level details, and having all these functions just return `IO ()` meant that I wasn't exploiting a lot of the safety that the type system could provide. It was essentially Haskell-flavoured Java[^java]! You can take a look at what the code looked like back then [here](https://github.com/joashc/cryptodiner/blob/34774247f1b45a02c6a24f5ae30ab66867835701/network/main.hs).

[^java]: Not to bash Java, et al. It's just that thinking in one language and "translating" it into another language tends to produce poor code in proportion to the size of the difference between the "thinking language" and the "writing language". And Java and Haskell are Very Different.

Alright, so we don't want a bunch of opaque `IO ()` functions, but wouldn't refactoring to use the free monad be really painful?

Not at all! Here's how you use free monads, in just seven easy steps!

<!--more-->

## Step 1: Create your operations
Free monads allow you to separate the semantics of your application from the details of its implementation in a very flexible way. They're basically an easy way to create a DSL that specifies only the bare minimum to get monadic behaviour and do-notation.

To start, you need to define the fundamental operations of your program. This is more of an art than a science, but there are a few guidelines:

- You want as little (ideally, none) implementation detail to spill over into your operations.
- If an operation can be composed of multiple, more basic operations, you should usually only create the most basic ones.
- You can make your operations polymorphic.

To define your fundamental operations, you create a sum type that will serve as your operators. Here's a simplified version of what I settled on for my chat program:

```haskell
data DcNodeOperator state error next =
    InitState next
  | AwaitStateCondition (state -> Bool) (state -> next)
  | GetState (state -> next)
  | GetUserInput (String -> next)
  | ModifyState (state -> state) next
  | DisplayMessage String next
  | GetRandomInt Int (Int -> next)
  | Throw error next
```

A few comments: 

- This is far from an ideal set of operations, but they used to be a lot worse!
- `DcNodeOperator` is polymorphic over the state type and the error type. This meant that I could use the same set of operations to describe both my client and server applications.
- `InitState` is a bit suspicious; it seems like an implementation detail rather than something that's fundamental to the semantics of my application.
- The `next` type represents the next action in your program. If an operation can't have a logical "next step" (`TerminateApplication`, for example), then you should just define the type without a `next` parameter.

## Step 2: Functorizing
Now we need to turn our operation type into a functor:

```haskell
instance Functor (DcNodeOperator state error next) where
  fmap f (InitState next) = InitState (f next)
  fmap f (AwaitStateCondition g h) = AwaitStateCondition g (f . h)
  fmap f (GetState g) = GetState (f . g)
-- ....and so on
```

This is rather mundane, mechanical work, so let's get the compiler to do it for us by turning on the `DeriveFunctor` extension:

```haskell
{-# LANGUAGE DeriveFunctor #-}
data DcNodeOperator state error next =
    InitState next
  | AwaitStateCondition (state -> Bool) (state -> next)
  --etc
  deriving (Functor)
```

## Step 3: Create the operation functions

Now we create functions to conveniently call[^call] our operations:

[^call]: In this context, "calling" the operation simply means wrapping it up in a `Free`.

```haskell
import Control.Monad.Free

initState :: Free (DcNodeOperator state error) ()
initState = Free (InitServer state error (Pure ()))

getState :: Free (GetState state error) state
getState = Free (GetState state error) id
-- etc
```

This is also rather mundane, mechanical work, so we can use a bit of Template Haskell to create all the functions for us:

```haskell
{-# LANGUAGE TemplateHaskell #-}
import Control.Monad.Free.TH

makeFree ''DcNodeOperator
```

## Step 4: Create the monad instance

Now we should pass some types to `DcPeerOperator` and give it a type alias:

```haskell
type DcPeerOperator = DcNodeOperator PeerState PeerError
```

and define the free monad over the newly created `DcPeerOperator` type:

```haskell
type DcPeer = Free DcPeerOperator
```

## Step 5: Write your application in your DSL
Let's put it all together and see what we've got so far:

```haskell
{-# LANGUAGE DeriveFunctor, TemplateHaskell #-}

import Control.Monad.Free
import Control.Monad.Free.TH

data DcNodeOperator state error next =
    InitState next
  | AwaitStateCondition (state -> Bool) (state -> next)
  | GetState (state -> next)
  | GetUserInput (String -> next)
  | ModifyState (state -> state) next
  | DisplayMessage String next
  | GetRandomInt Int (Int -> next)
  | Throw error next
  deriving (Functor)

makeFree ''DcNodeOperator

data PeerError =  ServerDisconnected | ServerTimeout | InvalidPeerState deriving (Show)
data PeerState = PeerState { peers :: [Peer], listenPort: Port, peerId :: String  }

type DcPeerOperator = DcNodeOperator PeerState PeerError

type DcPeer = Free DcPeerOperator
```

Believe it or not, this is all we need to start writing in our DSL[^dsl]! Here's what a simple program in our DSL looks like (ignore the `.~` and `^.` if you're not familiar with lenses):

[^dsl]: This is a big advantage to using the free monad. While you could implement the DSL yourself, there's a lot of places you can mess up. A lot of work has been done to make free monad DSLs rather quick and painless.

```haskell
initPeer :: DcPeer ()
initPeer = do
  initState
  displayMessage "What port do you want?"
  enteredPort <- getUserInput
  modifyState $ port .~ (parse enteredPort)
  state <- getState
  displayMessage $ "Using port: " ++ show state ^. port

awaitPeers :: DcPeer [Participant]
awaitPeers = do
  state <- awaitStateCondition $ (> 1) . numPeers
  return $ state ^. peers
```

Notice that we are free to start writing our program without worrying at all about the implementation! These functions we've defined return a `DcPeer`, which is a monad, so we can easily compose them into larger functions:

```haskell
peerProgram :: DcPeer ()
peerProgram = do
  initPeer
  peers <- awaitPeers
  displayMessage $ "Peers: " ++ show peers
```

`awaitPeers` looks just like it was defined as a fundamental operation, which is why you shouldn't define an operation if it can be produced from the composition of simpler ones. Happily, all these functions are entirely pure; they don't actually *do* anything except store all the operations into a value that can be interpreted later.

## Step 6: Write an interpreter
So now we need to create an interpreter for our free monad. Fortunately, even though we can go crazy and create large, complex programs with our DSL, we only need to write one interpreter function for each operation.

We need to pick a monad type that we want to "translate" our free monad into. Let's pick something simple for this example:

```haskell
type DcPeerIO :: StateT (PeerState) IO
```

Now we just map every possible operation of `DcPeerOperator` to this type:

```haskell
peerInterpreter :: DcPeerOperator (DcPeerIO next) -> DcPeerIO next
peerInterpreter (GetUserInput next) = do
  userInput <- liftIO getLine
  next userInput
peerInterpreter (GetState next) = get >>= next
peerInterpreter (DisplayMessage m next) = do
  liftIO $ putStrLn m
  next
peerInterpreter (GetRandomInt max next) = do
  num <- liftIO $ getRandomNumber max
  next num
-- etc
```


## Step 7: Run your program
Once we do that, we can pass any `DcPeer ()` to the interpreter and it'll interpret it:

```haskell
initialState = PeerState [] 0 ""

runPeer = runStateT (iterM peerInterpreter $ peerProgram) initialState
```

`iterM` recursively calls the interpreter for every "line" written in our DSL.

## What have we gained?
It's a really quite painless to refactor applications in this way, and I think it buys you two main benefits:

### Flexibility
Because you only need to write interpreters that cover the core operations of your application, you can completely refactor your implementation by just changing your interpreter. I moved from using the state monad to STM extremely easily, because references to the state monad weren't scattered all over the codebase; there were only a few places in the interpreter that I needed to change.

And because writing interpreters is so easy, you can keep the old interpreter, and write a completely new one, allowing you to make completely different implementations of the same application semantics! We could, for instance, create a web application just by writing a  different interpreter, so instead of:

```haskell
peerInterpreter (DisplayMessage m next) = do
  liftIO $ putStrLn m
```

we can write

```haskell
webPeerInterpreter (DisplayMessage m next) = do
  liftIO $ displayWebMessage m
```

or a debugging/testing interpreter

```haskell
debugInterpreter (GetUserInput next) = do
  randInput <- liftIO getRandomString
  liftIO $ putStrLn "User input requested, generated: " ++ randInput
  next randInput
```

#### Purity
Even though programs written in a free monad DSL can look imperative, they're actually completely pure. Every line in the DSL just wraps the monad with another layer of `Free`.

So now there's just one place where we do all our dangerous IO stuff- but that isn't the biggest advantage. You actually end up writing *less* IO code, because only your operations need to be interpreted.

There's something beautiful about being able to write extremely large programs in a completely pure DSL, and then having the freedom to map the resulting program onto an arbitrary monad with arbitrary side effects, simply by interpreting operations. It means that the amount of IO code in your programs scales with the size of your DSL rather than the size of the program, which can turn out to be a huge difference.
