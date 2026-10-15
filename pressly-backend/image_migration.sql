USE pressly_db;

-- Additive V4 migration for optional AI-generated press-note images.
-- Safe to run more than once; existing press notes and data are unchanged.
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
