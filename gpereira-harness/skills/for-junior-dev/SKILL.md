---
name: for-junior-dev
description: 'Pitches every explanation at a developer new to the codebase: plain words, short sentences, jargon unpacked the first time it appears. The code itself is unaffected. Invoke with /for-junior-dev; applies for the whole session until told to stop.'
disable-model-invocation: true
---

# For junior dev

Write so the reader understands each line as they read it, without holding a question open until later.

The reader here is competent but new. They can program. What they lack is *this* codebase, *this* domain, and the shorthand the team built up before they arrived. So the job is never to dumb the content down — it is to stop assuming the shorthand.

## Cut the nesting, not the facts

Simplifying fails in both directions. Cut the facts and you get something terse the reader still cannot act on. Pad it with restatement and the facts are buried in noise, which is the same failure wearing a friendlier face — and it is the more likely one here.

What comes out is **jargon and nesting**. What stays is **every fact, and the reason behind the change**. Length is not the target in either direction: the text runs as long as its content requires and not one sentence longer.

## What changes

Prose only — explanations, PR and commit messages, code comments, review notes, plans, handovers.

**Code stays exactly as it would be otherwise.** A junior reads and ships the same code as everyone else, and writing them a private, simplified dialect teaches them a codebase that does not exist. Explain the clever line; do not replace it.

## The levers

Reach for these in roughly this order — the early ones do most of the work.

1. **One idea per sentence.** Split on `which`, `, and`, and every semicolon. Long sentences are where a new reader loses the thread, more than any single hard word.
2. **Gloss the shorthand this team invented, not the vocabulary of the trade.** `N+1`, `race condition`, `cache`, `migration` — a developer meets these in their first month, and defining them reads as condescension. What actually blocks a newcomer is local shorthand: an internal service name, a domain term, a pattern this codebase uses and names oddly. Gloss those in one clause on first use, then carry on. When unsure which side a term sits on, ask whether it would appear in a first-year textbook; if it would, leave it alone.
3. **Say the actual name.** `UserService::resolve()`, not "the relevant service method". Vague references force the reader to guess, and a wrong guess costs them the rest of the paragraph.
4. **Replace pronouns that reach backwards.** "It" and "this" pointing at something two sentences ago is a comprehension cost with no upside. Repeat the noun.
5. **Give the order things happen in.** Most junior confusion is about sequence and cause, not vocabulary. Numbered steps beat a paragraph describing the same flow.
6. **Keep the reason, drop the derivation.** Why a change was made is what juniors are told least often and what transfers to the next problem, so it stays. A consequence the reader can work out from the sentence before is not a reason — it is padding.

## Over-explaining is the likelier failure

Writing for a newcomer pulls towards saying everything twice. Two shapes to catch:

- **Restating a consequence.** The previous sentence already established it. Saying it again in other words tells the reader you did not expect them to follow.
- **Defining what needs no definition.** See lever 2. A gloss on a term the reader already owns is a speed bump, and enough of them turn the whole text into something they skim.

Both come from writing to look thorough rather than to be read. Trust the reader to carry a fact forward one sentence.

## Words that quietly exclude

`just`, `simply`, `obviously`, `of course`, `trivially`. Each one tells the reader they were supposed to find this easy. When they do not, they conclude the gap is in them and stop asking — which is precisely the outcome to avoid.

Say the step instead. "Just wire it up" becomes "register it in `config/services.php` so the container can resolve it."

Spell out an acronym once, the first time it appears.

## When plain would be wrong

Accuracy wins over plainness. Some precise terms have no honest short synonym: `idempotent` is not "safe to run twice", and swapping it for that teaches the reader something they will later have to unlearn. Keep the precise word.

Whether it also needs a gloss is lever 2's call, not this section's — the term surviving does not mean a definition comes with it. Trading correctness for readability only moves the confusion further down the line, where it costs more.

## Worked example

**Before**
> The N+1 was resolved by eager-loading the relation in the repository, which also lets us drop the manual hydration in the presenter.

**After**
> The repository now eager-loads the relation, which fixes the N+1. The presenter's manual hydration goes away with it.

`N+1` and `eager-load` stay as they are: both are trade vocabulary, and defining them would add a clause each while telling the reader nothing they do not have. What changed is the nesting — the `which also lets us` chain became a second sentence, so each clause carries one idea.

The version that explains *why* the hydration can go is longer and worse. The reader already has it from the first sentence.

## Done when

Three conditions hold together:

1. Every piece of shorthand specific to this codebase or domain is glossed at first use, and nothing from the standard vocabulary is.
2. No fact from the original has gone missing.
3. No sentence exists only to restate the one before it.
