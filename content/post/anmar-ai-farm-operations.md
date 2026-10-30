---
title: "AI on the Farm: Connecting Conversation to Real Operations"
date: 2026-10-30T10:00:00-04:00
author: Anderson Pimentel
description: "Inside Anmar's private farm assistant: Telegram, Agno, LiteLLM and scoped operational APIs, with persistent memory and explicit limits on what the model can do."
tags: ["ai", "agriculture", "python", "software-architecture", "llmops"]
cover:
  image: /images/anmar-ai-architecture.svg
  alt: "Anmar farm assistant architecture: Telegram, Agno, model gateway and operational APIs"
  hiddenInSingle: true
draft: false
---

At our family farm, Serra Branca, a useful AI conversation starts with ordinary questions: how much milk was recorded today, which cows are lactating in a particular location, or how one animal's production changed over a period. The answers already belong to our operational systems. The challenge is making them accessible in a conversation while preserving their meaning and access rules.

That is the starting point of Anmar's agent platform. As of late October, a private Telegram assistant can consult milk production, herd summaries and production by animal, as well as historical statistics and comparisons. The broader plan includes specialists for milking, herd management, dairy production and sales. Today, the deployed pilot is one assistant, in one private conversation, with milk and herd tools connected.

## The applications come before the agent

Anmar has separate applications for farm operations, including milk, herd, cheese production and sales. They remain responsible for operational records and business rules. The assistant reads the relevant APIs through tools with deliberately limited interfaces.

This distinction becomes concrete in a question like “how many cows produced milk today?” Milk records can answer how many distinct animals have recorded production for that date. The herd application answers which animals are currently classified as lactating. Those are different populations. Adding the morning and afternoon animal counts would also count some cows twice.

Offline operation adds another boundary: a shift marked closed on the server does not prove that every device has synchronized. Missing records do not automatically mean zero production. The tool returns coverage and state alongside the values so the conversation can preserve those distinctions.

## Architecture: one worker, several controlled boundaries

[![Anmar AI architecture: a private Telegram conversation reaches a Python worker running Agno. The worker uses SQLite for conversation and delivery state, LiteLLM for model requests, and separate service credentials for milk and herd APIs.](/images/anmar-ai-architecture.svg)](/images/anmar-ai-architecture.svg)

*The deployed Telegram worker calls Agno directly. AgentOS also provides an authenticated HTTP interface for local execution and tests; it is not a public hop in the deployed chat path.*

| Component | Role in this implementation |
| --- | --- |
| Python 3.12 and Agno 3.1.10 | Compose the assistant, tools, instructions and personal memory. |
| Telegram worker | Accept the linked private chat, persist incoming work and deliver responses. |
| LiteLLM | Route OpenAI-compatible requests through configured model aliases and a scoped key with budget and rate controls. |
| DeepSeek pilot | Generate responses and tool calls; configured free fallbacks remain separate choices. |
| Anmar Apps and `anmar-auth` | Issue short-lived integration tokens and validate access at each operational app. |
| Milk and herd APIs | Supply current records, domain calculations, identities and historical analysis. |
| SQLite | Persist agent sessions/preferences and the channel's inbox/delivery state in separate databases. |
| Docker and Coolify on Oracle infrastructure | Run the ARM64 worker with persistent storage and supervised restart. |

The model connection follows LiteLLM's [OpenAI-compatible client interface](https://docs.litellm.ai/docs/proxy/client_setup/overview). Provider selection belongs to gateway configuration; farm authorization remains in application code.

### From a question to an answer

1. The worker receives a message from the linked Telegram user and chat, and records it before processing.
2. Agno receives the question, a bounded conversation history, the current capabilities and the required domain instructions.
3. The model requests a tool. The tool supplies the configured identity and farm scope, obtains an integration token and calls the relevant API. Credentials and farm authorization are not arguments chosen by the model.
4. The tool returns structured values with the relevant period, animal identity and coverage. Domain code performs calculations and validates consistency.
5. The model writes a response, and the worker persists the response and delivery outcome.

For an individual cow, the tool resolves the name or ear tag through Rebanho, then queries Leite. Repeated names require clarification. Historical analysis keeps the period and metric explicit; an average over days with records is not silently presented as an average over every calendar day.

## A running process still needs a valid identity

The first deployment exposed a simple operational failure: the bot remained running, but the human session it used to consult milk expired. Restarting the container could not repair that authentication boundary.

We replaced the human session with integration credentials. Anmar Apps issues five-minute tokens through Client Credentials; the client caches the bearer in memory and renews it before expiry. Each connected module has its own credential and audience, and the receiving app allows specific routes, methods and farm scope.

The Telegram identity and the API identity now have separate jobs. The first determines who may talk to this private pilot. The second determines what the software may read. Adding a new skill does not grant access to another farm or application.

## Memory is for preferences; tools are for facts

The assistant can save an explicitly requested presentation preference and recover it in a later session. This is persistent user memory, not model training. Agno's [agentic memory mechanism](https://docs.agno.com/memory/overview) supplies a tool for memory updates; our instructions restrict its purpose to durable preferences.

Milk totals, herd counts, permissions and business rules must come from the systems. A previous answer is not a fresh reading. We found a practical example after repairing authentication: an existing conversation still contained the old access error, and the model repeated that the integration was unavailable without calling the tool.

The fix supplies the backend's current capabilities alongside each new question. Replaying the old conversation then produced a fresh API call. It also showed why a successful test in a new session does not cover the experience of someone returning to a long-running conversation.

Domain procedures live in versioned `SKILL.md` files. An early test with optional loading called the milk tool but skipped its procedure and misdescribed a shift. Loading the relevant instructions into the initial context improved that case. Authorization, arithmetic and state validation still belong to deterministic code.

## Limits and delivery are part of the product

Short conversations worked with the initial free provider, but consecutive questions hit its token limit. The current DeepSeek pilot followed a small comparison of response behavior and availability, not a broad benchmark. Changing providers also changes data-retention assumptions; zero data retention has not been established for this pilot.

The worker now queues eligible transient model rate-limit failures, with up to four total attempts, preserving order and state across restarts. Credential and budget errors do not enter that retry loop. Runs involving memory tools are protected from automatic repetition. Context is limited to three completed rounds, with older tool results summarized while keeping useful parameters.

Telegram delivery has a different failure policy. A confirmed rate limit can retry the saved response. A connection failure with an unknown delivery outcome is recorded as uncertain rather than blindly sending the message again.

## What is working, and what is still ahead

The October 28 delivery records a complete run of 236 automated tests, followed by focused checks after review. The tests exercise real runtime and storage boundaries with controlled external responses. Separate acceptance checks used real APIs and models; those answer different questions from deterministic tests and do not establish unrestricted answer accuracy.

The private bot, milk/herd queries, historical analysis, integration-token renewal and bounded retry handling are deployed. The five named specialist bots and directors' group access remain planned. Proactive milk alerts have a deterministic monitoring foundation, but delivery is not activated. The virtual-farm interface and knowledge-base integration are also future work; the current assistant is not backed by a deployed document-retrieval service.

The most useful progress has been making an ordinary farm question travel through clear boundaries: a known person, an authorized tool, a current record and an answer whose limitations can be explained.
