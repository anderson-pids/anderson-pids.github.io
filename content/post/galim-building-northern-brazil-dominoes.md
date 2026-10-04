---
title: "Building Galim: A Domino Game from Northern Brazil"
date: 2026-10-01T12:05:00-04:00
author: Anderson Pimentel
description: "How a family domino variant became a TypeScript game engine and a local table with configurable rules and three bot players."
tags: ["game-development", "typescript", "brazil"]
draft: false
---

Galim is a domino game built around the rules Anderson and Ralph play in Northern Brazil. The name comes from *galo*, a call made during the game. Turning those rules into software meant making each detail explicit: when a player may pass, how a hand ends, and how the score is credited.

## Start with the rules

The game uses the standard 28 dominoes, dealt into four hands of seven, with no draw pile. Partners sit opposite each other. Players score from the open ends of the board in multiples of five, and the starting double can open four paths through the board.

There are several details around that core. A hand can end with a player playing their last tile (*batida*) or when the game is blocked (*fechamento*). The *galo* and announcements of multiple doubles add further rules and scoring choices. The match checks its target score only after the hand has been fully scored.

Encoding these decisions in a TypeScript engine gave the rules a single place to live. The engine validates tile ownership, matching sides, orientation, legal destinations, passes, and end-of-hand behavior. Explicit rule options keep variants visible instead of hiding them in interface code.

## Make the table playable

The local React table lets one person play against three bots: a partner and two opponents. Each bot has a selectable difficulty. The easier bots choose among legal moves, while the more advanced profile considers immediate points and possible replies using only public information and its own hand.

The interface handles announcements, automatic turns, scoring, hand history, and mobile layouts. Only the human player's hand is visible during play; the other hands are revealed when the hand ends so the result can be checked.

## Test complete hands

Testing a domino game means checking whole sequences, not only individual moves. Recorded simulations let the tests replay turns and compare the final score and credits. Browser tests exercise complete hands through the table, including blocked games, announcements, and tie-breaks.

Galim now has a local game that can run complete matches against bots, with continuous checks for its engine and web table. Online rooms, persistent sessions, and a full manual review of the experience remain future work. For now, the focus is making the local rules clear and the score explainable at the end of every hand.
