---
title: "Building Tribe Academy: A Learning Platform for Teams"
date: 2026-10-01T12:00:00-04:00
author: Anderson Pimentel
description: "Notes on building a multi-company learning platform, from team onboarding to progress tracking and platform administration."
tags: ["product-development", "education", "saas"]
draft: false
---

The idea for Tribe Academy came from a recurring need I saw across companies: keeping internal courses organized and following up on learning as part of professional development plans (PDIs) and onboarding. Teams need a place to organize learning materials, guide people through clear next steps, and follow up on progress without losing sight of who can access what.

That meant building more than a catalog of courses. The platform brings together organizations, teams, memberships, learning paths, assignments, and progress. Authors can organize a path into modules and activities, while learners can see their missions and pick up where they left off. Managers can review submitted work and follow progress for the people and paths they are responsible for.

## Designing for more than one organization

The multi-company model shaped many of the product decisions. Each organization has its own people, teams, paths, and settings. Platform administration is a separate role: it can manage plans and domains without granting access to a customer's learning content.

The free plan and organization limits also needed predictable behavior. When an organization reaches a limit, the platform should explain what happened and preserve its existing data. A plan change should not quietly delete learning materials or memberships.

## Learning needs a next step

A list of available paths is useful, but it does not always help someone decide what to do next. The personal mission view brings overdue work, returned activities, and upcoming deadlines forward. Inside a path, learners can resume an available activity, while completed work remains available for reference.

Authors can also choose between a list of activities and a map of learning steps. This changes how a path is presented while keeping its content and learner progress intact.

## Building the operational details

Invitations, authentication, private PDF materials, organization domains, and email limits all affect whether the product can be operated safely. Those parts need clear boundaries: private files stay private, organization access follows active membership, and platform administration remains distinct from customer content.

The project uses Next.js and TypeScript, with Supabase for PostgreSQL, authentication, and storage. Unit, integration, and browser tests help validate the rules across the application. The recent work also added an audited global email limit for Academy authentication and invitations, so delivery failures and repeated events are handled deliberately.

Tribe Academy is an evolving product. The work so far has focused on making learning paths usable by teams and making the platform manageable across organizations, while keeping access and data ownership explicit.
