---
description: "Spike: verify a command can arm the /goal evaluator"
---
# Goal-arming spike

Arm a session goal now, using the /goal mechanism, with exactly this condition:

"The transcript shows the output of `cat SPIKE_DONE.txt` printing the text
spike-ok — or stop after 3 turns."

After arming it, do NOT create the file this turn. End the turn by saying
"spike armed". On the next turn (if the evaluator drives one), create
SPIKE_DONE.txt containing "spike-ok" and print it with `cat SPIKE_DONE.txt`.
