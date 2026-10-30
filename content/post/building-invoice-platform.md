---
title: "Building an Invoice Platform: From a Sales Record to a Fiscal Document"
date: 2026-10-30T09:00:00-04:00
author: Anderson Pimentel
description: "How TribeSolutions is building a PHP, Laravel and PostgreSQL invoice platform: organization isolation, exact decimals, private certificates, XML and recovery from uncertain outcomes."
tags: ["product-development", "php", "laravel", "software-architecture"]
cover:
  image: /images/invoice-platform-architecture.svg
  alt: "Invoice platform architecture with implemented local modules and planned Sefaz integration"
  hiddenInSingle: true
draft: false
---

A sale of cheese at Anmar already has useful structure: a customer, individually identified pieces, weights, prices and payment records. Preparing the fiscal document introduces another set of responsibilities: issuer identity, tax configuration, numbering, certificates and the result returned by the authorization service.

We decided to build that boundary as a separate TribeSolutions product, with Anmar as its first customer. The intended entry points are a standalone operator portal and an integration API. Inventory, production and payments remain in the operational applications.

**This is a development account, not a launch announcement.** The local portal already supports registrations, draft preparation, PDF previews, offline XML signing and controlled recovery tests. No invoice has been transmitted to or authorized by Sefaz through this product. The integration API and the connection to Anmar Vendas are still planned.

## A deliberately narrow first use case

The agreed pilot concerns Anmar's internal sales in Roraima, starting with its own queijo coalho production. The product's initial target is goods invoices, NF-e model 55. Interstate sales, transfers, returns and other invoice models are outside this first slice.

A narrow scope lets us ask concrete questions about one workflow without pretending that a reference invoice defines every future transaction. Fiscal configuration is explicit, reviewed and versioned. The software does not infer a company's full tax treatment from a PDF or fill unknown fields just to make a preview work.

## Architecture: keep fiscal work behind one application boundary

[![Invoice platform architecture: the browser reaches a Laravel portal with organization checks. Services persist drafts and attempts in PostgreSQL, generate XML and PDF previews, and protect certificate material. A dashed boundary marks future external Sefaz transmission and the planned integration API.](/images/invoice-platform-architecture.svg)](/images/invoice-platform-architecture.svg)

*Solid boxes describe the local implementation. Dashed boxes are planned integrations. SOAP/HTTPS adapter code exists, but the application's default transport is disabled.*

| Technology | Why it is here |
| --- | --- |
| PHP 8.5 and Laravel 13 | Application services, authentication, forms, authorization and transactions. |
| Blade and CSS | A server-rendered portal for operators, without a separate frontend application. |
| PostgreSQL 17 | Organization data, draft versions, number allocations, attempts and audit records. |
| NFePHP `sped-nfe` 5.2.8 | XML construction and signing in the implemented offline flow. |
| NFePHP `sped-da` | DANFE preview generation from prepared XML. |
| `brick/math` | Exact decimal arithmetic for quantities, prices and rounding. |
| OpenSSL and phpseclib | Certificate inspection and certificate-chain work. |
| Docker, PHPUnit and Laravel Pint | Reproducible local services, behavior tests and formatting checks. |

[NFePHP's own guide](https://github.com/nfephp-org/sped-nfe/blob/master/docs/StartGuide.md) describes XML creation, signing and communication facilities. Those capabilities are building blocks: adopting the library does not establish that our issuer, configuration or application is ready for authorization.

## Isolation starts before a draft exists

The portal has organization membership and roles for administration, operation and consultation. Platform administration does not automatically grant access to a customer's invoices; support also needs explicit membership. Server-side services check that scope when loading and modifying records.

Authentication uses Argon2id passwords, encrypted database sessions, CSRF protection and login rate limits. Invitations are short-lived, single-use links whose tokens are stored as hashes. The current invitation flow copies links manually; it does not imply an email-delivery service.

Each issuer also has separate fiscal-environment configuration. Test preparation and production are distinct contexts throughout the model, not merely labels placed on the final page.

## A draft is a versioned record of what the operator reviewed

Drafts retain copies of the issuer, recipient, product and selected fiscal-profile data. Editing the catalog later does not silently rewrite what the operator reviewed. Refreshing those copies is an explicit action, and the typed price is preserved.

Updates carry a version. If another tab has changed the draft, the older form is rejected as a conflict while preserving the operator's input. This prevents an apparently successful save from erasing a newer review.

Quantities and prices use decimal arithmetic. A commercial subtotal is kept distinct from a validated fiscal total; missing coverage or unconfirmed configuration remains visible as a pending condition.

That separation also changed the preview experience. Initially, the familiar DANFE preview belonged to a prepared, numbered test request. An operator trying fictitious registrations could not reach it without completing fiscal prerequisites. We added a simpler commercial draft PDF that requires neither an A1 certificate nor a reserved number. It is clearly identified as having no fiscal value. The DANFE preview remains a separate step derived from XML.

## Protecting the A1 is a separate responsibility

An A1 file and its password are encrypted together using AES-256-GCM, with a dedicated vault key supplied outside the database. Ordinary portal views do not need to expose that material. Offline inspection checks whether the key can be used, certificate dates and the issuer identity encoded in the certificate.

Certificate-chain and revocation checks are separate from opening the file or verifying a signature. The implementation includes offline checking and trust-material tooling, but an operational trust package and the real issuer's readiness still need to be established before the first external test. A successful synthetic certificate test is evidence about the code path, not about a customer's real certificate.

## A timeout must not become another invoice

The most consequential failure case is a request whose response is lost. The application cannot safely conclude that the remote service rejected it. Preparing a new request with a new number would obscure the original attempt and could create a second document.

The local implementation preserves request identity, version, numbering and attempts. Database transactions and locks protect allocations and concurrent operations. Controlled simulations exercise a lost response followed by consultation, repeated requests, competing processes and interruption during processing.

The response reader also checks correlation: environment, invoice key, signed XML digest and protocol context must agree before it classifies a response as authorization evidence. Ambiguous or unsupported returns remain candidates for reconciliation. That classification alone does not establish trusted delivery from a real authorization service.

SOAP and mutual-TLS HTTPS adapters exist behind a transport interface. The application currently binds that interface to a disabled transport. This lets us test the recovery logic and preserve original payloads without accidentally treating local preparation as a transmission.

## Evidence so far, and the next boundary

The latest recorded local suite passed 258 tests with 4,212 assertions. Browser checks covered synthetic organizations on desktop and mobile; PDF previews were inspected separately. These results come from the implementation checkpoints, and were not rerun merely to write this article.

The first external homologation test is still ahead. It requires the real issuer's readiness, the appropriate certificate trust material, current official technical requirements and an explicitly enabled transmission/consultation flow. Production issuance, the public integration API, Anmar integration and operational deployment remain later milestones. Some of the current implementation is still local development work, beyond the last published branch commit.

Keeping the fiscal product separate makes its responsibility clear: prepare, submit and track a fiscal document with an auditable outcome. A future invoice cancellation must not silently reverse cheese inventory or payment records. Those operations belong to their own systems and require their own decisions.
