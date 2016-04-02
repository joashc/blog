---
title: Visualizing the Metropolis Algorithm
scriptName: metro.js
workerName: metro.worker.js
---

Let's say you're doing some sort of Bayesian analysis. You'll have a prior \\(P(\\theta)\\) over your model parameters \\(\\theta\\). You get some data \\(D\\), and you want to update on this data to get the posterior \\(P(\\theta\\vert D)\\), the updated distribution of the model parameters given \\(D\\). Let's wheel out Bayes' theorem and work out how to calculate \\(P(\\theta\\vert D)\\), which for convenience we'll call \\(\\pi(\\theta)\\):

$$\pi(\theta) = P(\theta\vert D)=\dfrac{P(D\vert\theta)P(\theta)}{P(D)}$$

Computing the numerator \\(P(D\\vert \\theta)P(\\theta)\\) is relatively straightforward. To calculate \\(P(D\\vert \\theta)\\), we can use a loss function to work how likely the observed data is, given the prior. And we have \\(P(\\theta)\\) because it's our prior, which means we can calculate \\(\\pi(\\theta)\\) up to the normalization constant \\(P(D)\\).

Computing the normalization constant is trickier. \\(P(D)\\) is the probability of seeing this data in the model, which means we have to integrate over all possible values of \\(\\theta\\):

$$P(D) = \int_{\Theta} P(D\vert\theta)P(\theta)\text{d}\theta$$

In most cases[^conj], this won't have a closed-form solution, and deterministic numerical integration can scale poorly with increasing dimensionality.

## Monte Carlo integration
Let's assume we can't easily compute this integral; we can turn to Monte Carlo methods to estimate it instead. If we can directly draw from the posterior distribution \\(\\pi(\\theta)\\)[^conj], we can simply compute the density of \\(\\pi(\\theta)\\) at a set of uniformly distributed values \\(\\theta_1, \\dots, \\theta_N\\) that cover a broad range of the parameter space for \\(\\theta\\):

[^conj]: Usually this is only feasible in simple Bayesian models, particularly those with conjugate priors.

$$\begin{split} P(D) &= \int_{\Theta} P(D\vert \theta)P(\theta)\text{d}\theta \\ &\approx \dfrac{1}{N}\sum_{i=1}^N P(D\vert\theta^{(i)})\end{split}$$

By the law of large numbers, our estimate will converge to the true distribution as \\(N\\) goes to infinity. But this only works if we can directly draw from \\(\\pi(\\theta)\\). Many Bayesian models use arbitrarily complex distributions over \\(\\theta\\) that we can't easily sample.

<!--more-->

## Importance sampling
Luckily, we can use *importance sampling* to help us approximate \\(\\pi(\\theta)\\), by sampling from a somewhat arbitrary distribution \\(q(\\theta)\\), and then correcting for the fact that we're sampling from \\(q(\\theta)\\) and not \\(\\pi(\\theta)\\):

$$\begin{split} P(D) &= \int P(D\vert\theta)P(\theta)\text{d}\theta \\ &= \int \dfrac{P(D\vert \theta)P(\theta)}{q(\theta)}q(\theta)\text{d}\theta\end{split}$$

In theory, all we've done is divide and multiply by \\(q(\\theta)\\); it shouldn't really matter what \\(q(\\theta)\\) is[^sing]. But now, instead of trying to draw samples from \\(\\pi(\\theta)\\), we can draw them from \\(q(\\theta)\\), which *can* be some distribution that's easy to sample from. We can think of this as sampling from \\(q(\\theta)\\), and correcting the sample by multiplying by its importance weight, given by:

[^sing]: Provided we didn't introduce any singularities

$$w(\theta) = \dfrac{P(D\vert \theta)P(\theta)}{q(\theta)}$$

Now, as before, we can use \\(q(\\theta)\\) to create a random set of samples for Monte Carlo integration:

$$\begin{split}P(D) &= \int w(\theta)q(\theta)\text{d}\theta \\ &\approx \dfrac{1}{N} \sum_{i=1}^N w(\theta^{(i)})\end{split}$$

Importance sampling is a very useful tool, but starts to become ineffective for \\(\\theta\\) of \\(\\geq 6\\) dimensions. In an high-dimensional parameter space, if you try to ensure that \\(q(\\theta)\\) has support everywhere that \\(\\pi(\\theta)\\) is large, \\(q(\\theta)\\) won't have enough probability mass to properly explore the space, and your realisations will be scattered too sparsely to be of any significance.

## Markov chain Monte Carlo
Markov chain Monte Carlo (MCMC) involves creating a Markov process with a stationary distribution \\(\\pi(\\theta)\\), and then running the simulation long enough to produce a chain that converges close enough to \\(\\pi(\\theta)\\) for our purposes.

One family of MCMC methods uses the Metropolis algorithm, which is incredibly simple to implement. It can be thought of as a random walk through the parameter space that's weighted to converge to the target distribution. Here's a simple visualization[^vis] of the Markov chains the Metropolis algorithm produces when it's run on the Rosenbrock function:

[^vis]: You can drag up and down on the text boxes to change the numbers. Holding Shift while dragging will increase the step size by 10x, while holding Control while dragging will reduce it by 10x.

```
mountPoint
```

Try reducing the variance to 0.001 and choosing a relatively low number of iterations. The acceptance rate will approach 100%, and as it does, the chain will reduce to a random walk. 

Now try setting the variance around 0.5, and increasing the number of iterations around 10,000. You'll see that regions of probability space with greater density[^rose] are more likely to be visited by the chain.

[^rose]: In this case, the greatest density is around the top right of the bend.

## The Metropolis algorithm

The Metropolis algorithm is really simple to implement; it can be written in a few lines of code. Given a starting point \\(\\theta^{t-1}\\), a single iteration of the algorithm looks like:

1. Perturb \\(\\theta^{t-1}\\) with a *proposal distribution* \\(q_t(\\theta^\*\\vert \\theta^{t-1})\\) to produce a proposal \\(\\theta^\*\\). For the Metropolis algorithm, this proposal distribution must be symmetric, so \\(q_t(\\theta_a\\vert\\theta_b) = q_t(\\theta_b\\vert\\theta_a)\\), for all \\(\\theta_a\\), \\(\\theta_b\\), and \\(t\\).
2. Calculate the ratio of posterior densities: $$r_\pi = \dfrac{\pi(\theta^*)}{\pi(\theta^{t-1})}$$ We can see that even if we can only calculate the unnormalized posterior, computing the ratio here will cause \\(P(D)\\) to cancel out, and we'll get a properly normalized term.
3. Set \\(\\theta^t\\): $$\theta^t = \begin{cases}\theta^* & \text{with probability} \min(1, r) \\ \theta^{t-1} & \text{otherwise}\end{cases}$$

Here's the Javascript implementation used on this page:

```javascript
function metropolis(dist, startPoint, variance, iterations) {
  let current = startPoint;
  let chain = [current];
  var oldLik = dist(...current);

  // Perturbs a number using a normal distribution
  const perturb = x => x + normalRandom(0, variance);

  // Construct chain
  for (var i=0; i < iterations; i++) {
    const candidate = map(perturb, current);
    const newLik = dist(...candidate);
    const acceptProbability = newLik / oldLik;

    if (Math.random() < acceptProbability) {
      // Accept candidate
      oldLik = newLik;
      current = candidate;
    }
    chain.push(current);
  }
  return chain;
};
```

In this case, the proposal distribution is the normal distribution centered at 0 with a user-selected variance, and our "posterior distribution" is actually just the Rosenbrock function. We also don't need to calculate \\(\\min(1, r)\\), because `Math.random()` always produces a value that's less than \\(1\\).

[^prop]: This is why Bayes' theorem is often written \\(P(\\theta\\vert D) \\propto P(D\\vert\\theta)P(\\theta)\\).

## Helping our intuition
Interestingly, just observing the algorithm operate in low dimensions gave me some intuition about its behaviour in higher dimensions.

### Proposal distribution
The proposal distribution can greatly affect the convergence of the chain. If the proposal distribution tends to produce very small steps[^small], the chain will traverse the probability space very slowly.

[^small]: Which happens in our visualization if the variance is very low

In our visualization, we can sort of see that the start point is in a rather featureless region of probability density, which means if we take tiny steps, \\(\\pi(\\theta^\*)\\) is very likely to be close to \\(\\pi(\\theta^{t-1})\\). The acceptance ratio will hover around \\(1\\), which means almost every proposal will be accepted, and the behaviour of the chain will be decided almost entirely by the proposal distribution.

If our proposal distribution makes very large steps, however, most of the proposals will be rejected. You can observe this behaviour by making the variance very large and noticing that the acceptance rate tends to drop. This means that you're basically doing importance sampling, and you'll need a prohibitive number of iterations to properly explore the probability space.

In practice, we generally target acceptance rates of around 30%.

### Burn-in
A chain is likely to spend its initial states trying to find some region of high density, and this groping search is unlikely to approximate the target distribution. It's standard practice to "burn-in" a chain by discarding the first, say, 50% of the chain, and only checking the remainder for convergence. This behaviour can be observed in our visualization if you set the variance to about 0.01; the first portion of the chain is generally spent wandering around the uninteresting portions of the probability space.


Results
-------
Once we're satisfied with the convergence of the chain, we can use it as an approximation for our target distribution. Here's how the Metropolis algorithm approximates the Rosenbrock function:

```
mountPoint
```

At a low number of iterations, the chain doesn't really explore much of the probability space, so we get a rather noisy look at a portion of the target distribution. If we increase the number of iterations to the hundred thousand range, we can see the familiar Rosenbrock arch shape emerge.

Increasing our iterations to the millions[^mill] (hold down the Shift key while dragging!) will give a clearer picture of the function, with a lot of detail around the global maximum at the top right of the arch.

[^mill]: This can take a while. The algorithm itself runs on a web worker so that the page doesn't lock up while it's running, but the final graphing needs to happen on the UI thread and can freeze up the page for a short time.

## Why does it converge?
We've got an intuitive understanding of why the chain is more likely to explore regions of higher density, but we don't have a proof- even an informal one- that the Markov chain will converge to the target distribution. Let's take a look at one now.

The Metropolis algorithm aims to create a Markov chain with \\(\\pi(\\theta)\\) as its stationary distribution. Because we've selected our proposal distribution to be symmetric, our chain is irreducible and aperiodic by construction. For reasons that I won't get into here, this means that it must have a unique stationary distribution. But why is this stationary distribution \\(\\pi(\\theta)\\)?

For an unspecified point \\(\\theta_a\\), the distribution of it having successor \\(\\theta_b\\) is given by integrating over all possible values of \\(\\theta_a\\):

$$\int \pi(\theta_a)q_t(\theta_b\vert \theta_a)\text{d}\theta_a$$

We've chosen \\(q_t(\\theta)\\) to be symmetric:

$$\pi(\theta_a)q_t(\theta_b\vert \theta_b) = \pi(\theta_b)q_t(\theta_a\vert \theta_b)$$

so we can substitute this in to get

$$\begin{split} \int \pi(\theta_a)q_t(\theta_b\vert \theta_a)\text{d}\theta_a &= \pi(\theta_b) \int q_t(\theta_a \vert \theta_b)\text{d}\theta_a
\\ &= \pi(\theta_b)\end{split}$$

because of course \\(\\int q_t(\\theta_a\\vert \\theta_b)\\text{d}\\theta_a = 1\\).

This means that the probability density of the chain moving to \\(\\theta_b\\), given that it's at \\(\\theta_a\\), is given by the density of the distribution \\(\\pi(\\theta_b)\\)!
