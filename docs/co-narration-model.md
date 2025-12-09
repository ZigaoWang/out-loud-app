# New Learning Interaction Model: Co-Narration

We introduce a new interaction paradigm designed specifically for learning through explanation. Instead of interrupting the user or providing passive summaries, the system collaborates with the learner to progressively construct a clear, accurate explanation of the topic. This model is grounded in the principles of the Feynman Technique while avoiding the common issues of intrusive prompting, over-correction, and irrelevant content.

---

## 1. Session Initialization

At the beginning of each session, the system asks the learner to specify the topic with sufficient precision (e.g., “Photosynthesis,” “Supply and Demand,” “Newton’s Second Law,” “TCP Handshake,” “Romeo and Juliet Act 3,” “Enzyme kinetics”).
If the description is too broad, the system requests one level of clarification, but does not repeatedly narrow the scope.

This step allows the AI to anchor its responses to the correct knowledge level (middle school, high school, undergraduate survey, etc.) while preventing scope drift.

---

## 2. Silent Listening Phase

Once the topic is set, the learner begins explaining in their own words.
During this phase, the system does not interrupt or attempt to correct. It gathers signals such as:

* pauses
* incomplete conceptual structures
* vague or ambiguous phrasing
* major omissions
* signs of uncertainty

This ensures that the learner maintains flow and does not feel interrogated.

---

## 3. Co-Narration Phase

The system intervenes only at natural pause points or clear conceptual gaps.
Interventions are concise and limited to one sentence. They fall into three categories:

1. **Targeted clarification prompt**
   Encourages the learner to elaborate on a specific missing piece.
   (“You mentioned the role of enzymes; you may want to specify what ‘lowering activation energy’ means.”)

2. **Micro-correction**
   A brief adjustment to prevent misconceptions.
   (“Diffusion is driven by concentration gradients, not active transport.”)

3. **Structural guidance**
   Suggesting the next logical component of the explanation.
   (“You can now distinguish between the light-dependent and light-independent stages.”)

The AI remains within the user’s declared knowledge level and does not introduce advanced, irrelevant, or university-level material unless explicitly requested.

---

## 4. Mini-Segment Reflection

After the learner completes a coherent segment or pauses for several seconds, the system provides a concise reflection:

* what the user has already articulated
* which key components are still missing
* one recommended next step

This is not a full summary; it is a co-constructed scaffold guiding the learner toward a complete and integrated explanation.

---

## 5. Completion Snapshot

At the end of the session, the system generates a brief conceptual map:

* concepts the learner successfully explained
* concepts partially covered
* concepts not yet addressed
* one diagnostic question to verify understanding

This output captures the learner’s current explanatory model without overwhelming them with feedback.

---

## 6. Content-Level Control

Throughout all stages, the system follows strict relevance constraints:

* stays within the learner’s chosen curriculum or level
* avoids unnecessary depth or tangential content
* avoids repeating what the learner already said
* limits the number of questions to prevent cognitive overload

Examples of supported topic ranges:
secondary school science, literature analysis, introductory economics, programming concepts, engineering fundamentals, world history, foundational mathematics, and more.