---
title: "Building Galim: A Domino Game from Northern Brazil"
date: 2026-10-01T12:05:00-04:00
lastmod: 2026-10-30
author: Anderson Pimentel
description: "Galim's evolution from a local domino game to persistent online tables, TV spectators, match history, rankings and event campaigns."
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

## October update: a table that survives beyond one session

Galim now has two ways to play. **Single player** keeps the local game against three bots, without requiring an account. **Multiplayer** lets one to four people sign in with Google and join the same room from their own phones or computers, filling the remaining seats with bots. The online version is deployed through Coolify. After testing it with our group, the next work focused on what happens around the moves: watching on a TV, reconnecting, leaving, finding a table and keeping results.

A room does not need to wait for another person. Its creator can fill the remaining seats with the existing characters — Tati, Bruno da ZL, or Rod do Alvorada — and change or remove those bots before starting. The table still has four seats and two partnerships. Players sitting opposite each other are partners. An online table with three bots still depends on the server and a connection.

The interface changes came from playing the game: controls are more compact, valid destinations are highlighted, and the rooster control for announcing a *galo* sits beside the player's hand. After a confirmed galo, the three passes are presented together before the player continues. The announcement still has to happen before playing the tile; the presentation does not change the scoring rules.

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

[![Galim online architecture: player and spectator browsers use filtered HTTP views from an authoritative Express server. PostgreSQL persists rooms, sessions and results before successful mutation responses.](/images/galim-online-architecture.svg)](/images/galim-online-architecture.svg)

*Online play shares the rules engine with local play, but moves, persistence and access checks belong to the server.*

| Part of the online game | Where it runs |
| --- | --- |
| Tile selection, board rendering and feedback | Each player's React client |
| Room seats, match state, rules and scoring | The Express server |
| Bot turns and required bot decisions | Server timers using the shared bot strategies |
| Human identity verification | Google sign-in, validated by the server |
| Profiles, sessions, room snapshots and completed results | PostgreSQL on a persistent volume |
| TV table | A read-only React view from a revocable spectator link |

The bots keep their single-player profiles and strategies. Their decisions receive only their own tiles and public information, even though the authoritative engine runs on the server. Their turns do not depend on the room creator keeping a browser timer running.

### A stale move is not a lost connection

One intermittent “reconnecting” message turned out to have a more specific cause. If another action had already advanced the room, the server rejected the client's old revision with HTTP 409. The interface treated that response as a disconnection, even though the server had answered normally.

The client now fetches the current room state after a revision conflict, without replaying the stale action. Actual network failures still show a connection warning, which clears after synchronization recovers. Tests cover both a failed action request and a failed refresh following a conflict.

A check of the Oracle host found available CPU, memory and disk capacity, no Galim container restarts or out-of-memory termination, and 30 successful API responses out of 30. That was a healthy sample at the time of inspection; it does not establish the cause of every past connection interruption.

## Recover the table, then record the result

Human profiles now survive application deployments. On a successful Google login, the server saves or updates the Google identity, name, email, optional profile image and login timestamps/count in PostgreSQL before issuing the session. An atomic update keeps concurrent logins from creating duplicate users.

Persistence now goes beyond profiles. Sessions and room snapshots survive application restarts. Snapshots preserve the current hand, score, decisions, substitutions and accepted request identifiers. The server restores that state instead of dealing another hand or applying a retried move again.

The runtime serializes room operations and commits changes to PostgreSQL before acknowledging them. A database ownership marker prevents a replaced process from continuing to write during deployment. If a commit fails with an uncertain outcome, the runtime stops serving room operations until recovery from the database. This remains a single active writer architecture, rather than a horizontally distributed game server.

Connection loss and voluntary departure have different rules. A disconnected player has 60 seconds before a bot temporarily takes over; returning restores control of the current hand. Confirming a voluntary departure makes the replacement permanent. If every human is absent, the match pauses instead of letting bots finish it alone. After five minutes without a return, the room closes without a winner. Watching on a TV does not extend that deadline, and a restart does not reset it.

Completed online matches feed private history and multiplayer rankings. History stores summaries, participants, rules and scores, not a tile-by-tile replay. Rankings separate all-human tables from tables involving bots or substitutions. The server records the result; it does not accept an online victory claimed by a browser.

Single-player matches started while signed in can also save a summary to that account. Because those results are calculated in the browser, they stay out of multiplayer rankings. Anonymous play remains available, and saving a completed result does not provide recovery of an unfinished local match.

## A shared TV and a lobby for finding tables

The host can now enable a spectator link that opens without Google sign-in. It shows the public board, score, moves, galo announcements and passes, without player controls. The server creates a separate projection and replaces account identifiers with seat identifiers; hiding elements in CSS would not protect the underlying data.

During play, spectators receive no private tiles. At the end of a hand, the remaining tiles are revealed so everyone can inspect the result, following the rule we confirmed after the initial spectator proposal. The next hand hides them again. The host can revoke the link, and enabling it again generates a new token.

The authenticated lobby adds public and private tables, with private as the default. People can search public tables by their players, request a seat and wait for the host to accept or decline. Concurrent requests cannot claim the same seat. This is table discovery; searching for available people outside those tables is still planned.

## Events and the first payment experiment

Event campaigns connect an online match to a physical giveaway. Each campaign has its own QR link, time window and stock. A signed-in participant must complete an eligible server-controlled match, winning or losing, to obtain a voucher. An authorized operator records the delivery, with one gift per account per campaign while stock lasts.

The interesting engineering problem is the last item: two operators must not deliver it twice, and retrying a delivery must not consume another unit. PostgreSQL transactions, unique records and stock audit entries protect that operation. The feature was deployed on October 26; actual event participation and physical distribution are separate from its automated validation.

A supporter package is also implemented with Stripe card checkout and AbacatePay Pix, verified webhooks and a badge/theme tied to the account. Payment and refund flows have been exercised in sandbox. **Real sales remain disabled as of this update.** That distinction matters: working integration code and test transactions are not a commercial launch.

## Test complete hands

Testing a domino game means checking whole sequences, not only individual moves. Recorded simulations let the tests replay turns and compare the final score and credits. Browser tests exercise complete hands through the table, including blocked games, announcements, and tie-breaks.

The October 26 event delivery passed **350 server tests across 45 suites and 98 browser end-to-end tests**. Coverage includes online play, persistence, spectator views and concurrent voucher redemption. Earlier increments also exercised recovery across server restarts, private history, ranking separation and solo-result retries with real PostgreSQL. These are recorded checks from those deliveries, not a new execution of the application suites for this article update. Automated authentication uses a controlled provider; it complements the group's real play experience.

## What remains ahead

The backlog includes finding available people, expanding the regional bot cast and supporting an explicit offline single-player experience. Commercial payments still need production activation. The implemented game already covers the table, its spectators and its results; the next decisions concern how people find it and keep returning.
