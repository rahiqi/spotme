# AGENT.md

## System Overview

This repository implements a **real-time location sharing system**.

Architecture:

* `front/` → Flutter mobile app (Android-first)
* `back/` → Rust real-time backend
* `docker-compose.yml` → full system orchestration

Goal:
Enable instant live location sharing between users with minimal latency and high scalability (target: 1000+ concurrent users).

---

# Core Principle

Build for:

* simplicity
* performance
* minimal overhead
* real-time responsiveness

Avoid:

* unnecessary abstraction
* over-engineering
* heavy dependencies

---

# Repository Structure

/front
Flutter mobile app

/back
Rust backend service

docker-compose.yml
full system orchestration

---

# Functional Requirements

## Frontend (Flutter)

The mobile app must:

### Core features

* user profile (name + profile picture)
* discover nearby online users
* select a user to share location with
* receive live location stream from selected users
* display live map updates

### Flow

1. User opens app
2. Taps: “Share my location with”
3. App scans for online users
4. User selects a target user
5. Target user receives instant notification
6. Upon acceptance:

   * both users see each other on a live map
   * updates stream every 5 seconds (configurable)

### Background behavior

Must support:

* continuous location tracking
* background execution using Android foreground service
* auto-reconnect WebSocket on drop

Default update interval:

* 5 seconds

Configurable via backend response.

---

## Backend (Rust)

Backend must be:

* real-time
* event-driven
* horizontally scalable
* stateless where possible

### Responsibilities

* user session management
* presence detection (online/offline)
* WebSocket connection handling
* routing location updates
* notification dispatch
* session pairing between users

---

# Communication Protocol

## Transport

Primary:

* WebSocket (real-time stream)

Fallback:

* HTTP REST (auth, metadata, bootstrap)

---

## Events

### Client → Server

* `auth`
* `start_presence`
* `stop_presence`
* `share_request`
* `location_update`
* `accept_share`

### Server → Client

* `user_online`
* `user_offline`
* `share_request_incoming`
* `share_accepted`
* `location_stream`

---

# Real-time Requirements

System must support:

* 1000 concurrent users minimum
* low latency updates (<200ms target inside local region)
* high frequency GPS updates (every 5s default)
* persistent WebSocket connections

---

# Backend Design (Rust)

Preferred stack:

* Tokio async runtime
* WebSocket framework (Axum or Actix Web)
* serde for serialization

Design constraints:

* no blocking calls in hot path
* memory-efficient message routing
* per-user connection mapping in memory
* optional Redis for scaling presence across nodes

---

# Scalability Model

### Phase 1 (single node)

* in-memory session map
* WebSocket routing directly in Rust server

### Phase 2 (multi-node ready)

* Redis pub/sub for cross-node message sync
* stateless Rust instances behind load balancer

---

# Data Model (simplified)

User:

* id
* name
* profile_image_url
* status (online/offline)

Location:

* user_id
* latitude
* longitude
* timestamp

Session:

* requester_id
* target_id
* status (pending/active/ended)

---

# Flutter Client Rules

## Architecture

Use:

* Riverpod (preferred)
* clean separation:

front/lib/
core/
features/
auth/
presence/
location/
map/
shared/

---

## Location Handling

* Android foreground service required
* geolocation permission must be persistent
* auto-restart tracking after app kill (if OS allows)

Update frequency:

* default: 5 seconds
* configurable via backend

---

## UI Behavior

* minimal UI
* map-centric experience
* fast transitions
* no heavy animations

---

# Docker Requirements

Entire system must run via:

docker-compose up --build

---

## Services

### back (Rust service)

* builds backend
* exposes WebSocket + HTTP API
* handles real-time routing

### front (Flutter build container)

* builds APK
* outputs artifact

---

# Docker Constraints

* no manual setup required
* deterministic builds
* reproducible environment

---

# Artifact Handling

Frontend build must:

1. generate APK
2. store in `/artifacts`
3. optionally upload to configured storage

Naming:

app-{git_sha}-{timestamp}.apk

Output:

* download URL
* file size
* checksum

---

# Performance Rules

Backend must:

* avoid allocations in hot paths
* reuse buffers where possible
* batch broadcast updates if needed
* avoid unnecessary JSON parsing in loops

Frontend must:

* avoid rebuild storms
* throttle location updates if needed
* use efficient map rendering

---

# Security Rules

* no hardcoded secrets
* all tokens via environment variables
* WebSocket must validate auth token on connect
* user can only access approved sessions

---

# Failure Handling

If any build fails:

* stop immediately
* show exact error
* do not mask failure
* propose minimal fix only

---

# Build Requirement (Strict)

After every change:

## Frontend

* flutter analyze
* flutter test (if exists)
* flutter build apk

## Backend

* cargo check
* cargo test
* cargo build --release

Then:

* run docker-compose build
* ensure system starts cleanly

---

# Output Format (Agent Response)

After each task:

DONE:

* files changed
* services affected
* build status
* artifact locations
* any warnings

If failure:

FAILED:

* root cause
* failing command
* minimal fix proposal

---

# Design Philosophy

This system is:

* real-time first
* mobile-first
* simplicity over complexity
* performance-critical backend

No unnecessary features should be introduced without explicit request.
