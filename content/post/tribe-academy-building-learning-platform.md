---
title: "Building Tribe Academy: A Learning Platform for Teams"
date: 2026-10-01T12:00:00-04:00
author: Anderson Pimentel
description: "Inside Tribe Academy: how a Next.js client-server flow connects learning paths to Supabase Auth, PostgreSQL policies, private PDFs and controlled email delivery."
tags: ["product-development", "education", "saas", "software-architecture"]
cover:
  image: /images/tribe-academy-dashboard.png
  alt: "Tribe Academy's authenticated learner dashboard"
  hiddenInSingle: true
draft: false
---

The idea for Tribe Academy came from a recurring need I saw across companies: keeping internal courses organized and following up on learning as part of professional development plans (PDIs) and onboarding. Teams need a place to organize learning materials, guide people through clear next steps, and follow up on progress without losing sight of who can access what.

[![Tribe Academy's authenticated learner dashboard, showing learning paths, progress, and recommended next steps](/images/tribe-academy-dashboard.png)](/images/tribe-academy-dashboard.png)

*The authenticated workspace brings learning progress and the next action into the same view. This account has no enrolled paths yet.*

Explore the published application at [tribe.academy.tribesolutions.com.br/app](https://tribe.academy.tribesolutions.com.br/app). Access requires an invitation from an organization.

That meant building more than a catalog of courses. The platform brings together organizations, teams, memberships, learning paths, assignments, and progress. Authors can organize a path into modules and activities, while learners can see their missions and pick up where they left off. Managers can review submitted work and follow progress for the people and paths they are responsible for.

## Designing for more than one organization

The multi-company model shaped many of the product decisions. Each organization has its own people, teams, paths, and settings. Platform administration is a separate role: it can manage plans and domains without granting access to a customer's learning content.

The free plan and organization limits also needed predictable behavior. When an organization reaches a limit, the platform should explain what happened and preserve its existing data. A plan change should not quietly delete learning materials or memberships.

## Learning needs a next step

A list of available paths is useful, but it does not always help someone decide what to do next. The personal mission view brings overdue work, returned activities, and upcoming deadlines forward. Inside a path, learners can resume an available activity, while completed work remains available for reference.

Authors can also choose between a list of activities and a map of learning steps. This changes how a path is presented while keeping its content and learner progress intact.

## Architecture: from the browser to the data

The application uses Next.js and TypeScript, with a shared Supabase backend for authentication, PostgreSQL and private file storage. The web application runs in a container managed through Coolify. A company's hostname identifies its workspace; active membership and database authorization determine what a person can access inside it.

[![Tribe Academy architecture: the browser communicates with the Next.js application over HTTPS. Server-side code uses Supabase Auth, PostgreSQL queries and RPCs, and private Storage. PDF access returns a short-lived signed URL; authenticated email hooks deliver through Resend.](/images/tribe-academy-architecture.svg)](/images/tribe-academy-architecture.svg)

*The main request and data boundaries. PDF delivery and authentication email use the separate flows described below.*

Next.js Server Components load the page's data on the server. Interactive components and forms send changes through Server Actions; route handlers handle operations such as opening a private PDF. The server-side Supabase client reads the user's session cookies, so ordinary learning queries and database function calls run in that user's context.

| Boundary | What crosses it | Where it is checked |
| --- | --- | --- |
| Browser → Next.js | Page requests, form fields and session cookies over HTTPS | Session, input and workspace checks on the server. |
| Next.js → Supabase data API | Queries and RPC calls with the user's session | PostgreSQL row-level security and permission checks in database functions. |
| Next.js → private Storage | A request to sign a specific material's object path | User-visible material lookup and hostname scope before a privileged signing operation. |
| Supabase Auth → email hook → Resend | A signed authentication event, followed by an email delivery request | Webhook signature, global budget reservation and idempotency. |

### What happens when a learner completes a step

1. The browser submits the enrollment, step, requested completion state and the revision it last read to a Server Action.
2. The action resolves the signed-in user and active organization, then loads an enrollment belonging to that learner and organization. An identifier supplied by the browser is not sufficient authorization.
3. It calls the PostgreSQL function `set_step_completion` through Supabase RPC, including `p_expected_revision`. Database rules validate the change; a stale revision becomes a conflict instead of silently overwriting newer work.
4. The action revalidates the dashboard and study page, then redirects the browser to the step with success or error feedback. The next render reads persisted progress. This flow uses requests and server rendering; it does not rely on a live subscription.

Text activities follow a similar path through `submit_activity`. If an activity changed in another session, the form retains the learner's answer and asks them to refresh before retrying. That detail matters when someone has spent time writing a response.

### Authentication and company isolation

Login starts with a server-side request to Supabase Auth for an email link. The authentication callback establishes the session, and the Next.js proxy refreshes it for protected pages. The login request does not create an unknown user automatically; access is organized through invitations and membership.

The application resolves registered hostnames to organizations and restricts the workspace to the user's active memberships. A cookie remembers the selected organization, but the server checks it against those memberships. PostgreSQL row-level security adds a second boundary for reads, while database functions enforce the permissions and rules for writes. Platform administration remains separate from access to a company's learning content.

### Opening a private PDF

The browser first requests `/api/materials/[id]` from the application. The handler authenticates the user, looks up a material visible to that user, and checks that it belongs to the hostname's organization when a tenant hostname is in use.

Only after those checks does a server-only Storage client create a signed URL valid for five minutes. The application redirects the browser to that URL, and Storage serves the PDF directly. The response uses `private, no-store` and `no-referrer`; the bucket stays private, and the privileged Storage credential stays on the server.

### Email as a controlled backend operation

Supabase Auth sends a signed event to `/api/auth/send-email`. The handler verifies the signature and reserves capacity in PostgreSQL before contacting Resend. Repeated events use an idempotency key, and delivery outcomes are recorded. Reserving capacity before the external request keeps concurrent deliveries subject to the same global limit, including failed attempts.

This separates authentication, authorization, file delivery and email into boundaries that can be tested independently, while keeping one application and a shared database manageable across companies.

## Building the operational details

Invitations, authentication, private PDF materials, organization domains, and email limits all affect whether the product can be operated safely. Those parts need clear boundaries: private files stay private, organization access follows active membership, and platform administration remains distinct from customer content.

The project uses Next.js and TypeScript, with Supabase for PostgreSQL, authentication, and storage. Unit, integration, and browser tests help validate the rules across the application. The recent work also added an audited global email limit for Academy authentication and invitations, so delivery failures and repeated events are handled deliberately.

Tribe Academy is an evolving product. The work so far has focused on making learning paths usable by teams and making the platform manageable across organizations, while keeping access and data ownership explicit.
