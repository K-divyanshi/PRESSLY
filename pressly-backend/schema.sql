USE pressly_db;
-- Pressly database schema
-- Target: MySQL 8.0+
-- Apply to a dedicated local database, e.g. pressly_db.
-- Character set supports English and Hindi. Passwords must be hashed by the backend.
-- Run this file only against the intended development database.

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS press_note_status_history;
DROP TABLE IF EXISTS press_note_versions;
DROP TABLE IF EXISTS press_notes;
DROP TABLE IF EXISTS press_note_templates;
DROP TABLE IF EXISTS users;

SET FOREIGN_KEY_CHECKS = 1;

CREATE TABLE users (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    full_name VARCHAR(120) NOT NULL,
    email VARCHAR(254) NOT NULL,
    password_hash VARCHAR(255) NOT NULL COMMENT 'Server-generated password hash; never plaintext.',
    role ENUM('author', 'approver') NOT NULL DEFAULT 'author'
        COMMENT 'MVP policy permits an author to approve their own note; approver role is reserved for authorized reviewers.',
    is_active TINYINT(1) NOT NULL DEFAULT 1,
    last_login_at DATETIME(3) NULL,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    CONSTRAINT uq_users_email UNIQUE (email),
    CONSTRAINT chk_users_full_name CHECK (CHAR_LENGTH(TRIM(full_name)) >= 2),
    CONSTRAINT chk_users_email_nonempty CHECK (CHAR_LENGTH(TRIM(email)) > 0),
    INDEX idx_users_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
COMMENT='Pressly user accounts; passwords are always hashed in the application.';

CREATE TABLE press_note_templates (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    template_key VARCHAR(60) NOT NULL,
    name_en VARCHAR(120) NOT NULL,
    name_hi VARCHAR(160) NOT NULL,
    description_en VARCHAR(500) NULL,
    description_hi VARCHAR(700) NULL,
    is_active TINYINT(1) NOT NULL DEFAULT 1,
    sort_order SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    CONSTRAINT uq_press_note_templates_key UNIQUE (template_key),
    INDEX idx_templates_active_sort (is_active, sort_order)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
COMMENT='Reusable structure/tone metadata; templates must never introduce event facts.';

INSERT INTO press_note_templates
(template_key, name_en, name_hi, description_en, description_hi, is_active, sort_order)
VALUES
('general_event', 'General Event', 'सामान्य कार्यक्रम',
 'General institutional event or programme press note.',
 'सामान्य संस्थागत कार्यक्रम के लिए प्रेस नोट।', 1, 10),
('inauguration_launch', 'Inauguration / Launch', 'उद्घाटन / शुभारंभ',
 'Opening, inauguration, or launch announcement.',
 'उद्घाटन या शुभारंभ की घोषणा।', 1, 20),
('workshop_seminar_conference', 'Workshop / Seminar / Conference', 'कार्यशाला / संगोष्ठी / सम्मेलन',
 'Academic or professional workshop, seminar, or conference.',
 'शैक्षणिक या व्यावसायिक कार्यशाला, संगोष्ठी या सम्मेलन।', 1, 30),
('achievement_award', 'Achievement / Award', 'उपलब्धि / पुरस्कार',
 'Verified achievement, award, or recognition announcement.',
 'सत्यापित उपलब्धि, पुरस्कार या सम्मान की घोषणा।', 1, 40),
('institutional_announcement', 'Institutional Announcement', 'संस्थागत घोषणा',
 'Official announcement by an institution or organization.',
 'किसी संस्था या संगठन की आधिकारिक घोषणा।', 1, 50);

CREATE TABLE press_notes (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    owner_user_id BIGINT UNSIGNED NOT NULL,
    template_id BIGINT UNSIGNED NOT NULL,
    title VARCHAR(240) NOT NULL COMMENT 'Usually the event/programme name; may be edited by the owner.',
    language ENUM('en', 'hi') NOT NULL,
    status ENUM('draft', 'in_review', 'changes_requested', 'approved') NOT NULL DEFAULT 'draft',
    current_version_number INT UNSIGNED NOT NULL DEFAULT 0
        COMMENT '0 only before the first saved snapshot; otherwise points to the current immutable version number.',
    event_name VARCHAR(240) NOT NULL,
    event_description TEXT NULL,
    event_date DATE NULL,
    event_time TIME NULL,
    time_zone VARCHAR(80) NULL COMMENT 'IANA zone preferred, e.g. Asia/Kolkata; optional if time is not supplied.',
    venue VARCHAR(240) NULL,
    institution_name VARCHAR(240) NULL,
    organizer VARCHAR(240) NULL,
    participant_count INT UNSIGNED NULL,
    participant_categories JSON NULL,
    activities JSON NULL,
    outcomes JSON NULL,
    speakers JSON NULL COMMENT 'Array of objects such as {name, designation}; only supplied facts.',
    approved_quotes JSON NULL COMMENT 'Array of user-supplied, approved quotations and attribution.',
    contact_info JSON NULL COMMENT 'Optional official contact fields supplied by the user.',
    additional_instructions TEXT NULL,
    source_facts_json JSON NOT NULL COMMENT 'Canonical extensible snapshot of all validated user-provided facts.',
    content_json JSON NOT NULL COMMENT 'Structured press-note output: headline, dateline, openingParagraph, bodyParagraphs, etc.',
    missing_information JSON NULL,
    warnings JSON NULL,
    requires_human_review TINYINT(1) NOT NULL DEFAULT 1,
    approved_by_user_id BIGINT UNSIGNED NULL,
    approved_at DATETIME(3) NULL,
    deleted_at DATETIME(3) NULL COMMENT 'Soft deletion; excluded from ordinary queries.',
    last_generated_at DATETIME(3) NULL,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    CONSTRAINT fk_press_notes_owner FOREIGN KEY (owner_user_id) REFERENCES users(id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_press_notes_template FOREIGN KEY (template_id) REFERENCES press_note_templates(id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_press_notes_approver FOREIGN KEY (approved_by_user_id) REFERENCES users(id)
		ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT chk_press_notes_participant_count CHECK (participant_count IS NULL OR participant_count >= 0),
    CONSTRAINT chk_press_notes_approval_metadata CHECK (
        (status = 'approved' AND approved_by_user_id IS NOT NULL AND approved_at IS NOT NULL)
        OR (status <> 'approved' AND approved_by_user_id IS NULL AND approved_at IS NULL)
    ),
    CONSTRAINT chk_press_notes_version_positive CHECK (current_version_number >= 0),
    INDEX idx_notes_owner_updated (owner_user_id, deleted_at, updated_at),
    INDEX idx_notes_owner_status (owner_user_id, deleted_at, status, updated_at),
    INDEX idx_notes_template (template_id),
    INDEX idx_notes_approved_by (approved_by_user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
COMMENT='Current saved state; updates and immutable version snapshots must be written in a transaction.';

CREATE TABLE press_note_versions (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    press_note_id BIGINT UNSIGNED NOT NULL,
    version_number INT UNSIGNED NOT NULL,
    created_by_user_id BIGINT UNSIGNED NOT NULL,
    action_type ENUM('initial_save', 'user_edit', 'ai_revision', 'restore', 'approval_snapshot') NOT NULL,
    title_snapshot VARCHAR(240) NOT NULL,
    language_snapshot ENUM('en', 'hi') NOT NULL,
    template_id_snapshot BIGINT UNSIGNED NOT NULL,
    source_facts_snapshot JSON NOT NULL,
    content_snapshot JSON NOT NULL,
    missing_information_snapshot JSON NULL,
    warnings_snapshot JSON NULL,
    status_snapshot ENUM('draft', 'in_review', 'changes_requested', 'approved') NOT NULL,
    change_summary VARCHAR(500) NULL,
    restored_from_version_number INT UNSIGNED NULL,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    CONSTRAINT uq_note_version_number UNIQUE (press_note_id, version_number),
    CONSTRAINT fk_versions_note FOREIGN KEY (press_note_id) REFERENCES press_notes(id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_versions_creator FOREIGN KEY (created_by_user_id) REFERENCES users(id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_versions_template FOREIGN KEY (template_id_snapshot) REFERENCES press_note_templates(id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_versions_restored_from FOREIGN KEY (press_note_id, restored_from_version_number)
        REFERENCES press_note_versions(press_note_id, version_number)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT chk_versions_number_positive CHECK (version_number >= 1),
    INDEX idx_versions_note_created (press_note_id, created_at),
    INDEX idx_versions_creator (created_by_user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
COMMENT='Immutable saved snapshots. Never UPDATE or DELETE version rows during normal application operations.';

CREATE TABLE press_note_status_history (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    press_note_id BIGINT UNSIGNED NOT NULL,
    version_number INT UNSIGNED NULL,
    actor_user_id BIGINT UNSIGNED NOT NULL,
    previous_status ENUM('draft', 'in_review', 'changes_requested', 'approved') NULL,
    new_status ENUM('draft', 'in_review', 'changes_requested', 'approved') NOT NULL,
    action VARCHAR(40) NOT NULL COMMENT 'e.g. created, submitted_for_review, changes_requested, approved, approval_revoked, restored.',
    comment VARCHAR(1000) NULL,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    CONSTRAINT fk_status_history_note FOREIGN KEY (press_note_id) REFERENCES press_notes(id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_status_history_actor FOREIGN KEY (actor_user_id) REFERENCES users(id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_status_history_version FOREIGN KEY (press_note_id, version_number)
        REFERENCES press_note_versions(press_note_id, version_number)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    INDEX idx_status_history_note_time (press_note_id, created_at),
    INDEX idx_status_history_actor_time (actor_user_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
COMMENT='Append-only audit trail of important workflow transitions; insert in same transaction as status changes.';

-- Implementation notes:
-- 1. Save/edit/revise/restore/status transition: begin transaction, lock press_notes row,
--    validate current status/version, write current row, insert version if content changed,
--    insert status history if status changed, then commit.
-- 2. Version rows and history rows are append-only in application code.
-- 3. MySQL cannot express the current-version foreign key cleanly with this insert order;
--    enforce current_version_number against press_note_versions in the transaction/service layer.
-- 4. For all reads and writes, scope private note queries by both id and owner_user_id,
--    and require deleted_at IS NULL except for explicit administrative recovery (not in MVP).

-- Additive feature tables. Existing installations can run feature_migration.sql alone.
CREATE TABLE IF NOT EXISTS user_categories (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  name VARCHAR(160) NOT NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  CONSTRAINT uq_user_category_name UNIQUE (user_id, name),
  CONSTRAINT fk_user_categories_user FOREIGN KEY (user_id) REFERENCES users(id)
    ON UPDATE RESTRICT ON DELETE CASCADE,
  INDEX idx_user_categories_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS event_reminders (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  title VARCHAR(240) NOT NULL,
  event_date DATE NOT NULL,
  event_time TIME NULL,
  note VARCHAR(1000) NULL,
  completed_at DATETIME(3) NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  CONSTRAINT fk_event_reminders_user FOREIGN KEY (user_id) REFERENCES users(id)
    ON UPDATE RESTRICT ON DELETE CASCADE,
  INDEX idx_event_reminders_user_date (user_id, event_date, completed_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS password_reset_tokens (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  token_hash CHAR(64) NOT NULL,
  expires_at DATETIME(3) NOT NULL,
  used_at DATETIME(3) NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  CONSTRAINT uq_password_reset_token_hash UNIQUE (token_hash),
  CONSTRAINT fk_password_reset_user FOREIGN KEY (user_id) REFERENCES users(id)
    ON UPDATE RESTRICT ON DELETE CASCADE,
  INDEX idx_password_reset_user_expiry (user_id, expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Optional V4 image storage. Existing installations should run image_migration.sql.
CREATE TABLE IF NOT EXISTS press_note_images (
  press_note_id BIGINT UNSIGNED NOT NULL,
  mime_type VARCHAR(32) NOT NULL,
  image_data MEDIUMBLOB NOT NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (press_note_id),
  CONSTRAINT fk_press_note_images_note FOREIGN KEY (press_note_id)
    REFERENCES press_notes(id) ON UPDATE RESTRICT ON DELETE CASCADE,
  CONSTRAINT chk_press_note_images_mime CHECK (mime_type IN ('image/png','image/jpeg','image/webp'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
