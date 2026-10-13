# Story continuation — "The Third Slot" (draft, not implemented)

The main game ends at the living-room table: the player chooses the version they can live
with, Noa answers in the morning, the credits say "You can keep walking the rooms." This draft
is an optional **after-story** that starts in that free-roam morning. It must not explain the
night: like the main story it only adds pieces, and each ending keeps its own meaning.

## The hook already in the game

- Noa's tape box upstairs has **three empty slots** (`box_empty`).
- The study holds tapes "2 of 3": *"Second tape is missing."* (`tapes_study`)
- The last tape is labelled *"do not rewind"*, and the storm recording "remembers it wrong".

So one tape has never been found. The continuation is about **the third slot**.

## Beats

### 10 — Daylight (free roam)
- Morning light, rain stopped, birds faint outside. Every door is open, the radio upstairs
  plays a weather report (no voices from the past any more).
- Small changes per ending (only one object each, like the table):
  1. *He left* — the family photo is back on the hall wall, straight.
  2. *He came back* — the back door is unlocked now, standing a hand's width open.
  3. *Memory is incomplete* — Mom's letter lies open on Eitan's old desk upstairs.
- Objective: "Walk the house once more."

### 11 — The third slot
- In Eitan's old room (upstairs) the child's drawing has come off the wall. Behind it, a cassette
  case with Eitan's own handwriting from when he was ten: *"For when I'm grown up."*
- The tape is Eitan as a child, recording "the noises of the house" for a school project:
  rain, the fridge, Mom humming, and — at the end — three knocks, and his own small voice saying
  *"Dad's home."* Then he stops the tape.
- The player now knows Eitan himself was there and heard the knocks. It confirms none of the
  three versions: a child decided what the knocks meant, and the family kept his version.

### 12 — The gate
- Noa's car stops at the gate (sound only, then she is a silhouette by the mailbox; she never
  comes inside). The phone buzzes: *"I'm outside. You don't have to come out."*
- The player can walk to the gate, or stay in the house.
  - Walk out: a short exchange through the gate (text + her voice), she asks what was on the
    third tape. The player can **tell her** or **keep it**. Either way she says
    *"Okay. Then that's ours now."*
  - Stay inside: after a while the car drives off; a last text: *"Next time, I'll knock three
    times. You can decide what it means."*
- End: the house in full daylight, front door open, the street ordinary.

## New content needed

| Item | Where | Notes |
|---|---|---|
| Child's tape + case | Eitan's old room, behind `Child's drawing` | new clue `child_tape`, tape transcript in `data/tapes.json` |
| Per-ending morning object | hall wall / back door / Eitan's desk | reuse `_apply_ending_table` pattern |
| Weather report radio | storage room radio | voice line (VoxCPM2) |
| Noa at the gate | front gate, mailbox | silhouette only, phone texts + voice |
| Choice "tell her / keep it" | gate | reuse the endings panel |

## Implementation notes

- New chapters 10–12 after `start_morning()`; objectives via `OBJECTIVES` + `_chapter_ready()`.
- Voices: add the child Eitan and the weather reader to `AudioManager.CAST` and generate them with
  VoxCPM2 (see CLAUDE.md). The child's tape should go through the "Tape" bus.
- Keep the brief's rules: no jump scares, no monsters, no white flashes; silence is allowed.
