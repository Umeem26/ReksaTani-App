# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
