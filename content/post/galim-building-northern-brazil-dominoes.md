---
title: "Building Galim: A Domino Game from Northern Brazil"
date: 2026-10-01T12:05:00-04:00
lastmod: 2026-10-08
author: Anderson Pimentel
description: "Galim now has online rooms for two to four people, server-controlled bots, private hands, and persistent Google profiles alongside its local React game."
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

## October 8 update: bring the table online

Galim now has two ways to play. **Single player** keeps the local game against three bots, without requiring an account. **Multiplayer** lets two to four people sign in with Google and join the same room from their own phones or computers. The online version is deployed through Coolify, and we have been able to play it with a real Google account.

A room does not need to wait for four people. Its creator can fill the remaining seats with the existing characters — Tati, Bruno da ZL, or Rod do Alvorada — and change or remove those bots before starting. The table still has four seats and two partnerships, with at least two humans. Players sitting opposite each other are partners.

The latest interface changes came from playing the game: the mode buttons disappear after a match starts, and the rooster control for announcing a *galo* now sits beside the player's hand. The announcement still has to happen before playing the tile.

## Start with the rules

The game uses the standard 28 dominoes, dealt into four hands of seven, with no draw pile. Partners sit opposite each other. Players score from the open ends of the board in multiples of five, and the starting double can open four paths through the board.

There are several details around that core. A hand can end with a player playing their last tile (*batida*) or when the game is blocked (*fechamento*). The *galo* and announcements of multiple doubles add further rules and scoring choices. The match checks its target score only after the hand has been fully scored.

Encoding these decisions in a TypeScript engine gave the rules a single place to live. The engine validates tile ownership, matching sides, orientation, legal destinations, passes, and end-of-hand behavior. Explicit rule options keep variants visible instead of hiding them in interface code.

## Make the table playable

The local React table lets one person play against three bots: a partner and two opponents. Each bot has a selectable difficulty. The easier bots choose among legal moves, while the more advanced profile considers immediate points and possible replies using only public information and its own hand.

The interface handles announcements, automatic turns, scoring, hand history, and mobile layouts. Only the human player's hand is visible during play; the other hands are revealed when the hand ends so the result can be checked.

## Single-player architecture: the game runs in the browser

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

## Multiplayer architecture: the server owns the match

Hiding opponents' tiles in the interface is enough for the local experience, but the browser still holds that entire local match. Online play uses a different boundary: an Express server runs the same TypeScript engine and sends each player a filtered view. During a hand, that view contains the player's own tiles, the public board and opponents' tile counts. Other hands are revealed only when the hand ends.

Synchronization currently uses HTTP requests, with the browser polling the room every 800 milliseconds. A move carries the room revision and a request identifier. The server checks the account, seat, turn and move before applying it; repeated requests cannot score the same action twice. There is no WebSocket transport in this version.

| Part of the online game | Where it runs |
| --- | --- |
| Tile selection, board rendering and feedback | Each player's React client |
| Room seats, match state, rules and scoring | The Express server |
| Bot turns and required bot decisions | Server timers using the shared bot strategies |
| Human identity verification | Google sign-in, validated by the server |
| Saved human profiles | PostgreSQL on a persistent volume |

The bots keep their single-player profiles and strategies. Their decisions receive only their own tiles and public information, even though the authoritative engine runs on the server. Their turns do not depend on the room creator keeping a browser timer running.

### A stale move is not a lost connection

One intermittent “reconnecting” message turned out to have a more specific cause. If another action had already advanced the room, the server rejected the client's old revision with HTTP 409. The interface treated that response as a disconnection, even though the server had answered normally.

The client now fetches the current room state after a revision conflict, without replaying the stale action. Actual network failures still show a connection warning, which clears after synchronization recovers. Tests cover both a failed action request and a failed refresh following a conflict.

A check of the Oracle host found available CPU, memory and disk capacity, no Galim container restarts or out-of-memory termination, and 30 successful API responses out of 30. That was a healthy sample at the time of inspection; it does not establish the cause of every past connection interruption.

## Save people before building rankings

Human profiles now survive application deployments. On a successful Google login, the server saves or updates the Google identity, name, email, optional profile image and login timestamps/count in PostgreSQL before issuing the session. An atomic update keeps concurrent logins from creating duplicate users.

The database runs privately beside the application, with a persistent volume. The schema and application connection have been checked in production; the new profile records will be populated on subsequent logins. Storage tests use a real PostgreSQL instance, including new connections and simultaneous updates.

This persistence currently covers **profiles**. Online rooms and sessions still live in one server instance's memory, and restarting it loses both. A disconnected player's seat remains reserved, so play waits if their turn arrives. Match history, rankings and automatic replacement of an absent player have not been implemented yet.

## Test complete hands

Testing a domino game means checking whole sequences, not only individual moves. Recorded simulations let the tests replay turns and compare the final score and credits. Browser tests exercise complete hands through the table, including blocked games, announcements, and tie-breaks.

The October 8 delivery passed **221 server tests across 20 suites and 35 browser end-to-end tests**. Those checks include complete online hands with four browser sessions, mixed human/bot rooms, private hands, reconnection, the relocated rooster control and profile persistence. Public checks also covered starting a local game, the mobile layout, API availability and the redirect to Google sign-in. Automated authentication scenarios use a controlled provider; they complement the real-account play experience rather than replacing it.

## Next: leaving, history and spectators

The next implementation work has three product decisions to settle. When someone leaves, should a bot take over, and how long should a temporary disconnection reserve a seat? Should multiplayer rankings separate mixed tables from tables with four humans? Should a creator's spectator link work without Google sign-in?

The intended history will distinguish single-player and multiplayer results, while rankings will apply only to multiplayer. Online results need to be recorded by the server, once per completed match, rather than trusting a victory reported by a browser.

Spectators are a planned read-only role, enabled by the room creator. The goal is to watch the public table and score without exposing private hands or providing player controls. That would also support a shared TV display while each player uses a phone. These spectator, departure and ranking features are next steps, not part of the current release.
