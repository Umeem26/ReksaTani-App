# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- **Repository layout**: The Flutter app moved from `reksatani_app/` to the repository root, with file history kept through `git mv`. CI no longer sets a working directory.
- **Documentation**: New English `README.md`. The previous technical notes (architecture, limitations, test status, setup) moved to `docs/TECHNICAL.md`, with outdated statements marked as updated.
- **Grading**: Grade A/B/C is decided by a human checklist rubric (`v0.1-draf`); the TFLite model only suggests the commodity.
- **Sync and balances**: Transactions are upserted on `id_lokal`, and balances are recomputed from the base balance plus transactions.

### Fixed
- **Disbursements**: Kasbon disbursements (grade `-`) now pass the Atlas validator and reach the cloud.
- **GPS**: A failed location is stored as null and left out of the Atlas document, instead of being saved as 0,0.

### Added
- `ml/train_sawit.py` (draft retraining script for the oil palm grader) and `ml/NOTICE.md` with attribution for the public datasets.

## [1.1.0] - 2026-06-09

### Added
- **PCD Scanner & ML-based Object Detection**: Real-time PCD camera screen and ML-based image segmentation and grading services.
- **OCR Nota Fisik**: Text Recognition services to extract physical receipt data (weight in kg and price).
- **Two-Stage TFLite Model Pipeline**: Implemented multi-commodity grading (gabah, kelapa sawit, kopi).
- **Automatic Image Quality Validation**: Real-time scanning validation with automatic brightness adjustment for low-light conditions.
- **Authentication Gatekeeper**: Integrated a secure splash screen with RBAC (Role-Based Access Control) authentication.
- **Local Storage / Offline Cache**: Added Hive type adapters for transaction caching.
- **Security**: Upgraded authentication to use Bcrypt password hashing.
- **UI Enhancements**: Added commodity category filtering, customized icons, and resolved dashboard layout overflows.

### Changed
- **Environment Management**: Migrated configuration files from `flutter_dotenv` to the secure `envied` code generation tool.
- **Sync & Cache Logic**: Optimized the reactive refreshing cache and auto-sync manager.

### Fixed
- **Detection Reliability**: Resolved the bug causing 0% confidence on the real-time preview stream.
- **User Language**: Updated popup message copy for better local language friendliness.
