Medication Tracker

A lightweight medication tracking app that allows users to manage medications, sync them with a remote API, and receive local reminders.
This project was built as a take-home technical exercise with an emphasis on architecture, maintainability, and correctness, rather than visual polish.

Features

1. Medication Management
	•	Add medications with:
	•	Name
	•	Dosage
	•	Frequency (daily, twice daily, weekly, as needed)
	•	Edit existing medications
	•	Delete medications
	•	View a list of all medications
	•	Data is persisted via the provided REST API and cached locally

2. Reminder System (Bonus – Implemented)
	•	Local notifications scheduled based on medication frequency
	•	Supports:
	•	Daily
	•	Twice daily
	•	Weekly
	•	Notifications are:
	•	Updated when a medication is edited
	•	Cancelled when a medication is deleted
	•	Rebuilt centrally after sync to avoid stale reminders

3. API Integration
	•	REST API integration via LiveMedicationAPIClient
	•	Supports:
	•	Create
	•	Read (list + single)
	•	Update
	•	Delete
	•	Robust error handling for:
	•	Non-2xx responses
	•	Structured API error envelopes
	•	404 conflict resolution during sync

⸻

Architecture Overview

High-level structure:
	•	Views (SwiftUI)
	•	MedicationListView
	•	NewMedicationView
	•	EditMedicationView
	•	MedicationDetailView
	•	View Models
	•	Handle UI state and user intent
	•	Delegate persistence and sync to lower layers
	•	Repository Layer
	•	DefaultMedicationRepository
	•	Orchestrates API + local store
	•	Keeps views and view models unaware of networking details
	•	Sync Layer
	•	MedicationSyncActor
	•	Actor-isolated conflict resolution
	•	Handles:
	•	Local vs remote updates
	•	Deletes (including 404 semantics)
	•	Creation of missing remote records
	•	Persistence
	•	SwiftData for local storage
	•	Used as an offline cache and local source of truth
	•	Notifications
	•	MedicationNotificationScheduler
	•	Centralised scheduling and cancellation
	•	View-independent (not tied to UI lifecycle)

This separation ensures that:
	•	Business rules live outside views
	•	Sync logic is deterministic and testable
	•	Notification behavior does not depend on specific screens being opened

⸻

Notification Handling (Important Design Note)

Notification logic does not depend on any specific screen being opened.

Instead:
	•	Notifications are cancelled immediately when a medication is deleted
	•	Notifications are fully rescheduled after:
	•	Sync operations
	•	Medication edits
	•	This guarantees notifications never fire for:
	•	Deleted medications
	•	Inactive medications
	•	As-needed medications
	•	Medications with reminders turned off

This avoids a common real-world bug where stale notifications remain registered indefinitely.

⸻

Testing Strategy

The test suite focuses on high-value behavior, not raw coverage.

What is tested
	•	Model correctness (initializers, Codable round-trips)
	•	API client request construction and decoding
	•	SwiftData store upsert and delete semantics
	•	Repository orchestration (API → store → save)
	•	Sync conflict resolution:
	•	Remote wins
	•	Local wins
	•	Deletion edge cases
	•	Notification scheduling behavior for different frequencies

What is intentionally not tested
	•	SwiftUI layout and styling
	•	Apple framework internals (e.g. UNUserNotificationCenter)
	•	Snapshot or UI tests

The goal is to protect business logic and data correctness, rather than UI rendering.

⸻

Architecture Decision Record (ADR)

1. Architecture Pattern

Decision
Use MVVM with SwiftUI, backed by a Repository layer and an Actor-based sync component.

Rationale
SwiftUI is a declarative framework, and MVVM maps naturally to its state-driven model.
Views remain lightweight, ViewModels handle UI state and intent, and business logic lives outside the UI layer.
This provides strong separation of concerns without unnecessary abstraction.

⸻

2. Navigation / Routing

Decision
Use SwiftUI’s native NavigationStack with view-driven navigation.

Rationale
The navigation flow is simple and hierarchical.
A custom router or coordinator would add complexity without improving clarity or correctness.

⸻

3. Simplicity Over “Correctness”

Decision
Fully reschedule notifications after sync or edits instead of computing minimal diffs.

Rationale
Incremental notification diffing would be more “correct” but significantly more complex.
Rescheduling guarantees correctness, avoids stale notifications, and keeps the logic easy to reason about, with negligible performance cost.

⸻

What I’d Add With More Time
	•	UI tests for key flows, lack of time.
	•	Background sync triggers
	•	Accessibility improvements
	•	Saving notification to backend (requires backend changes)
	•	User friendly error reporting
	•	Analytics and error reporting hooks
	•	And another 1000 details for a production ready App...
