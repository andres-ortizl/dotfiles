---
name: wait-what
description: "Stop. That last message did not land: explain it again, simpler."
disable-model-invocation: true
---

Wait, I don't understand where you've got to. Explain your last message again:

1. Start with where we are: the task, and the one thing your last message was about.
2. Give the user-visible effect and one concrete example: the input, what happens today, what should happen.
3. Then the mechanism, in Simplified Technical English: one idea per sentence, active voice, one term per meaning.
4. Explain each piece of jargon in one line. Restate every item you mention; never point back at an earlier turn ("option B", "point 3").
5. Use the repository's own terms. If it has a `GLOSSARY.md`, use the words in it.
6. If a decision is open, end with it alone, as one question.

Keep it shorter than the message you are replacing.

Adapted from `wait-what` in [mattpocock/skills](https://github.com/mattpocock/skills) (MIT).
