# Home Assistant Configuration Management

This repository manages Home Assistant configuration files with automated validation, testing, and deployment. It runs in an isolated devcontainer with pixi for dependency management.

## Before Making Changes

**Always consult the latest Home Assistant documentation** at https://www.home-assistant.io/docs/ before suggesting configurations, automations, or integrations. HA updates frequently and syntax/features change between versions.

## Project Structure

- `config/` - Contains all Home Assistant configuration files (synced from HA instance)
- `tools/` - Validation and testing scripts
- `pixi.toml` - Pixi project config (dependencies and tasks)
- `Makefile` - Commands for pulling/pushing configuration (loads .env)
- `.claude-code/` - Project-specific Claude Code settings and hooks
  - `hooks/` - Validation hooks that run automatically
  - `settings.json` - Project configuration
- `.devcontainer/` - Devcontainer setup for isolated, portable development

## Environment Setup

Dependencies are managed by **pixi** (not venv). All commands run via `pixi run` or `make` (which uses `pixi run python` internally).

```bash
pixi install          # Install all dependencies
pixi run pull         # Pull config from HA
pixi run push         # Validate + push to HA
pixi run validate     # Run validation suite
```

## Rsync Architecture

This project uses **two separate exclude files** for different sync operations:

| File | Used By | Purpose |
|------|---------|---------|
| `.rsync-excludes-pull` | `make pull` | Less restrictive |
| `.rsync-excludes-push` | `make push` | More restrictive |

**Why separate files?**
- `make pull` downloads most files including `.storage/` (excluding sensitive auth files) for local reference
- `make push` never overwrites HA's runtime state (`.storage/`)

## What This Repo Can and Cannot Manage

### SAFE TO MANAGE (YAML files)
- `automations.yaml` - Automation definitions
- `scenes.yaml` - Scene definitions
- `scripts.yaml` - Script definitions
- `configuration.yaml` - Main configuration
- `secrets.yaml` - Secret values

### NEVER MODIFY LOCALLY (Runtime State)
These files in `.storage/` are managed by Home Assistant at runtime. Local modifications will be **overwritten** by HA on restart or ignored entirely.

### Entity/Device Changes (Manual Only)
Do not change entities or devices programmatically from this repo. Make changes in the Home Assistant UI:
- Settings > Devices & Services > Entities > Edit

### Reloading After YAML Changes
- Automations: `POST /api/services/automation/reload`
- Scenes: `POST /api/services/scene/reload`
- Scripts: `POST /api/services/script/reload`

## Workflow Rules

### Before Making Changes
1. Run `pixi run pull` to ensure local files are current
2. Identify if the change affects YAML files or `.storage/` files
3. YAML files: edit locally, then `pixi run push`
4. `.storage/` files: use the HA UI only (manual changes)

### Before Running `pixi run push`
1. Validation runs automatically - do not push if validation fails
2. Only YAML configuration files will be synced (`.storage/` is protected)

### After `pixi run push`
1. Reload the relevant HA components (automations, scenes, scripts)
2. Verify changes took effect in HA

## Available Commands

### Configuration Management
- `pixi run pull` - Pull latest config from Home Assistant instance
- `pixi run push` - Push local config to Home Assistant (with validation)
- `pixi run backup` - Create backup of current config
- `pixi run validate` - Run all validation tests

### Validation Tools
- `pixi run python tools/run_tests.py` - Run complete validation suite
- `pixi run python tools/yaml_validator.py` - YAML syntax validation only
- `pixi run python tools/reference_validator.py` - Entity/device reference validation
- `pixi run python tools/ha_official_validator.py` - Official HA configuration validation

### Entity Discovery Tools
- `pixi run entities` - Explore available Home Assistant entities
- `pixi run python tools/entity_explorer.py` - Entity registry parser and explorer
  - `--search TERM` - Search entities by name, ID, or device class
  - `--domain DOMAIN` - Show entities from specific domain (e.g., climate, sensor)
  - `--area AREA` - Show entities from specific area
  - `--full` - Show complete detailed output

## Validation System

### Core Goal
- Verify all agent-produced configuration and automation changes before saving YAML files to Home Assistant
- Never generate, save, or push YAML changes that fail validation

### Layers
1. **YAML Syntax Validation** - Ensures proper YAML syntax with HA-specific tags
2. **Entity Reference Validation** - Checks that all referenced entities/devices exist
3. **Official HA Validation** - Uses Home Assistant's own validation tools

### Automated Validation Hooks
- **Post-Edit Hook**: Runs validation after editing any YAML files in `config/`
- **Pre-Push Hook**: Validates configuration before pushing to Home Assistant
- **Blocks invalid pushes**: Prevents uploading broken configurations

## Home Assistant Instance Details

- **Host**: Configure in `.env` file (`HA_HOST` variable)
- **SSH Key**: Configure SSH access in `~/.ssh/config`
- **Config Path**: /config/ (standard HA path)
- **Version**: Compatible with Home Assistant Core 2024.x+

## Entity Naming Convention

### Format: `location_room_device_sensor`

**Structure:**
- **location**: `home`, `office`, `cabin`, etc.
- **room**: `basement`, `kitchen`, `living_room`, etc.
- **device**: `motion`, `heatpump`, `sonos`, `lock`, etc.
- **sensor**: `battery`, `tamper`, `status`, `temperature`, etc.

### Examples:
```
binary_sensor.home_basement_motion_battery
media_player.home_kitchen_sonos
climate.home_living_room_heatpump
lock.home_front_door_august
```

### Claude Code Integration:
- When creating automations, always ask the user for input if there are multiple choices for sensors or devices
- Use the entity explorer tools to discover available entities before writing automations
- Follow the naming convention when suggesting entity names in automations
