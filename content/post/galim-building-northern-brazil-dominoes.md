---
title: "Building Galim: A Domino Game from Northern Brazil"
date: 2026-10-01T12:05:00-04:00
author: Anderson Pimentel
description: "Inside Galim: a React table, a TypeScript rules engine, and the browser-side flow that turns a player's move into a scored domino hand."
tags: ["game-development", "typescript", "brazil", "software-architecture"]
cover:
  image: /images/galim-gameplay.png
  alt: "Galim's playable table, with team scores and three bot players"
  hiddenInSingle: true
draft: false
---

I had made games before, back when I was in college, but the idea for this one came during the pandemic. Dominoes are popular across Northern Brazil, including a point-scoring variant played in many homes. Galim is simply the name we gave this kind of game, not the name of the broader game category. Ralph and I play it with a set of regional rules, and turning those rules into software meant making each detail explicit: when a player may pass, how a hand ends, and how the score is credited.

[![A Galim hand in progress against three bots](/images/galim-gameplay.png)](/images/galim-gameplay.png)

*The local table: one human player, three bots, and a score that can be traced back to each action.*

The published game is available at [galim.tribesolutions.com.br](https://galim.tribesolutions.com.br/).

## Start with the rules

The game uses the standard 28 dominoes, dealt into four hands of seven, with no draw pile. Partners sit opposite each other. Players score from the open ends of the board in multiples of five, and the starting double can open four paths through the board.

There are several details around that core. A hand can end with a player playing their last tile (*batida*) or when the game is blocked (*fechamento*). The *galo* and announcements of multiple doubles add further rules and scoring choices. The match checks its target score only after the hand has been fully scored.

Encoding these decisions in a TypeScript engine gave the rules a single place to live. The engine validates tile ownership, matching sides, orientation, legal destinations, passes, and end-of-hand behavior. Explicit rule options keep variants visible instead of hiding them in interface code.

## Make the table playable

The local React table lets one person play against three bots: a partner and two opponents. Each bot has a selectable difficulty. The easier bots choose among legal moves, while the more advanced profile considers immediate points and possible replies using only public information and its own hand.

The interface handles announcements, automatic turns, scoring, hand history, and mobile layouts. Only the human player's hand is visible during play; the other hands are revealed when the hand ends so the result can be checked.

## Architecture: the game runs in the browser

The playable local version is a React application built with Vite. Its TypeScript rules engine lives under `server/src/game`, but the web application imports that code directly into its browser bundle. The directory name does not mean that a move makes a network request: the local table executes the engine in the player's browser.

[![Galim architecture: a static host delivers the React application; inside the browser, the UI calls the TypeScript engine and supplies a limited observation to the bots. Results update the board and score without a gameplay API.](/images/galim-architecture.svg)](/images/galim-architecture.svg)

*The current local mode. Arrows inside the browser represent function calls and state updates, not HTTP requests.*

The responsibilities are split across a few concrete components:

| Component | Responsibility |
| --- | --- |
| React table | Collect the selected tile and destination; display turns, feedback, board and score. |
| `Match` | Coordinate successive hands, accumulated scores, the target and tie-breaks. |
| `Hand` | Validate ownership and turns; apply plays, passes, announcements and hand completion. |
| `Board` and scoring rules | Check legal connections and open ends; calculate the credits associated with an action. |
| Bot strategy | Choose from legal moves using its own tiles and the public board. |

### From a click to the next turn

1. The player selects a tile and a destination in the React table. The interface checks that it is the human's turn and that no required announcement or feedback is blocking input.
2. The event handler calls `hand.play(player, piece, branch)`. The engine checks the move and updates the hand, board and scoring state. An invalid move produces an error rather than a partially applied play.
3. React renders the updated state: the tile's new position, the open-end total, team scores and any result or announcement. A revision counter triggers a render after changes to the engine object.
4. On a bot turn, a timer passes the public board, that bot's own tiles and its legal moves to `chooseBotTurn`. Its chosen move goes through the same engine validation. Required decisions and feedback pause automatic play.

This gives the local table immediate responses without a gameplay API, a database or a network round trip for each turn. The trade-off is that the match lives in browser memory: reloading the page does not restore a saved match.

### The boundary for online play

Hiding opponents' tiles in the interface is enough for the local experience, but it is not a security boundary: the browser holds the complete local match. A multiplayer version needs a server to own that state and send each player only the information they may see.

There is already groundwork in the repository for Google sign-in and an explicit per-player view. Those pieces are separate from the published local game. Online rooms, a gameplay transport, persistent sessions and reconnection remain unfinished; the diagram above does not imply that they are available. In particular, there is no live WebSocket gameplay flow to describe yet.

## Test complete hands

Testing a domino game means checking whole sequences, not only individual moves. Recorded simulations let the tests replay turns and compare the final score and credits. Browser tests exercise complete hands through the table, including blocked games, announcements, and tie-breaks.

Galim now has a local game that can run complete matches against bots, with continuous checks for its engine and web table. Online rooms, persistent sessions, and a full manual review of the experience remain future work. For now, the focus is making the local rules clear and the score explainable at the end of every hand.
