---
title: Pronouncing "Gadsby"
---

I was reading about a lipogrammatic novel called *Gadsby: A Story of Over 50,000 Words Without Using the Letter “E”*, by Ernest Vincent Wright, when I wondered how the lack of an overt letter “E” affected the pronunciation of the work.

A bit of Googling[^1] led me to [NLTK](http://www.nltk.org/), a natural-language toolkit for Python. I typed:

```python
import nltk
```

and the hard part was already done for me.

<!--more-->

Soon I had a hacky script:

```python
import nltk
import re

pronDict = nltk.corpus.cmudict.dict()

def flatten(list):
    return [x for xs in list for x in xs]

def normalizePhoneme(phoneme):
    return re.sub("\d+", "", phoneme)

def wordMatchesPhonemes(phonemes, word):
    if not word in pronDict: return False
    prons = pronDict[word]
    # Flatten pronounciations into a set of normalized phonemes.
    wordPhonemes = map(normalizePhoneme, set(flatten(prons)))
    return any([wp in phonemes for wp in wordPhonemes])

def wordsMatchingPhonemes(text, phonemes):
    words = set(re.sub("[^\w| ]", "", text.lower()).split())
    return filter(lambda word: wordMatchesPhonemes(phonemes, word), words)
```

[^1]: There are some questions you'll never know the answer to. But nowadays we have Google, and the set of these unanswerable questions are a great deal smaller.

When passed a text and a list of phonemes, the `wordsMatchingPhonemes` function returns a list of the words that contain at least one of these phonemes.

Moby Dick, a text where the author made no special effort to avoid the letter “E”, contains at least one "E" sound in 59% of its words[^2].

[^2]: The phonemes EM, ER, EH, EY, IY, and EM were used to discover words containing “E” sounds.

When we analyse Gadsby, a text that contains no words with the letter “E”, we find that only 42% of its words contained at least one “E” sound. It is still a large proportion, however, demonstrating (despite Wright’s Herculean efforts) the cardinality of the “E” sound to the English language.
