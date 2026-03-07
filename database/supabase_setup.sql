-- =====================================================
-- DATABASE: Maternal & Child Health Information System
-- PostgreSQL (Supabase) Version
-- =====================================================
-- url: 'https://buvseyqcdacctlupznya.supabase.co',
-- anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ1dnNleXFjZGFjY3RsdXB6bnlhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI2MzE2NTUsImV4cCI6MjA4ODIwNzY1NX0.VPh8ZZFqdeFyb8YuMxllbJJa-nWl4VXNq74o6-Itjjw',
-- =========================
-- ACCOUNTS & SECURITY
-- =========================
CREATE TABLE accounts (
    account_id BIGSERIAL PRIMARY KEY,
    email_address VARCHAR(255) UNIQUE,
    password_hash VARCHAR(255),
    account_type VARCHAR(20) NOT NULL CHECK (account_type IN ('admin', 'midwife', 'mother')),
    first_name VARCHAR(100),
    middle_name VARCHAR(100),
    last_name VARCHAR(100),
    extension_name VARCHAR(100),
    phone_number VARCHAR(20),
    verification_code VARCHAR(100),
    verification_expires TIMESTAMP,
    is_verified BOOLEAN DEFAULT FALSE,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended')),
    reset_code VARCHAR(6),
    reset_expires TIMESTAMP,
    last_login_token VARCHAR(128),
    last_login_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE password_history (
    pass_history_id BIGSERIAL PRIMARY KEY,
    account_id BIGINT NOT NULL REFERENCES accounts(account_id) ON DELETE CASCADE,
    password VARCHAR(255) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    replaced_at TIMESTAMP
);
CREATE TABLE audit_trail (
    audit_id BIGSERIAL PRIMARY KEY,
    account_id BIGINT REFERENCES accounts(account_id) ON DELETE
    SET NULL,
        action VARCHAR(100) NOT NULL,
        table_name VARCHAR(100),
        old_data JSONB,
        new_data JSONB,
        description TEXT,
        action_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        ip_address VARCHAR(45)
);
-- =========================
-- BARANGAY & STAFF
-- =========================
CREATE TABLE bhc (
    bhc_id BIGSERIAL PRIMARY KEY,
    bhc_name VARCHAR(255) NOT NULL
);
CREATE TABLE midwives (
    midwife_id BIGSERIAL PRIMARY KEY,
    account_id BIGINT NOT NULL UNIQUE REFERENCES accounts(account_id) ON DELETE CASCADE,
    assigned_bhc_id BIGINT NOT NULL REFERENCES bhc(bhc_id) ON DELETE RESTRICT
);
-- =========================
-- MOTHERS & MEDICAL PROFILE
-- =========================
CREATE TABLE mothers (
    mother_id BIGSERIAL PRIMARY KEY,
    account_id BIGINT NOT NULL UNIQUE REFERENCES accounts(account_id),
    assigned_bhc_id BIGINT REFERENCES bhc(bhc_id) ON DELETE CASCADE,
    birthdate DATE,
    house_number VARCHAR(50),
    street VARCHAR(100),
    barangay VARCHAR(100),
    city_municipality VARCHAR(100),
    province VARCHAR(100),
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
    height DECIMAL(5, 2),
    weight DECIMAL(5, 2),
    blood_type VARCHAR(100)
);
CREATE TABLE emergency_contacts (
    emergency_contact_id BIGSERIAL PRIMARY KEY,
    mother_id BIGINT NOT NULL REFERENCES mothers(mother_id) ON DELETE CASCADE,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    middle_name VARCHAR(100),
    extension_name VARCHAR(20),
    phone_number VARCHAR(20),
    affiliation VARCHAR(100),
    email_address VARCHAR(255),
    house_number VARCHAR(50),
    street VARCHAR(100),
    barangay VARCHAR(100),
    city_municipality VARCHAR(100),
    province VARCHAR(100),
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE medical_conditions (
    med_condition_id BIGSERIAL PRIMARY KEY,
    mother_id BIGINT NOT NULL REFERENCES mothers(mother_id) ON DELETE CASCADE,
    condition_name VARCHAR(255) NOT NULL,
    diagnosis_date DATE,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'resolved')),
    remarks TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE allergies (
    allergy_id BIGSERIAL PRIMARY KEY,
    mother_id BIGINT NOT NULL REFERENCES mothers(mother_id) ON DELETE CASCADE,
    allergen VARCHAR(255) NOT NULL,
    diagnosis_date DATE,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'resolved')),
    treatment TEXT,
    remarks TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
-- =========================
-- PREGNANCY & CARE
-- =========================
CREATE TABLE pregnancies (
    pregnancy_id BIGSERIAL PRIMARY KEY,
    mother_id BIGINT NOT NULL REFERENCES mothers(mother_id) ON DELETE CASCADE,
    pregnancy_risk_level VARCHAR(10) CHECK (
        pregnancy_risk_level IN ('low', 'medium', 'high')
    ),
    last_menstrual_period DATE,
    expected_date_of_delivery DATE,
    status VARCHAR(10) NOT NULL CHECK (status IN ('ongoing', 'ended')),
    outcome VARCHAR(20) CHECK (
        outcome IN (
            'live_birth',
            'stillbirth',
            'miscarriage',
            'abortion',
            'ectopic'
        )
    ),
    outcome_date DATE,
    is_outcome_date_estimated BOOLEAN DEFAULT FALSE,
    gestational_age_at_end DECIMAL(4, 1),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ended_at TIMESTAMP
);
CREATE TABLE prenatal_checkups (
    prenatal_checkup_id BIGSERIAL PRIMARY KEY,
    pregnancy_id BIGINT NOT NULL REFERENCES pregnancies(pregnancy_id) ON DELETE CASCADE,
    midwife_id BIGINT NOT NULL REFERENCES midwives(midwife_id) ON DELETE RESTRICT,
    age_of_gestation DECIMAL(4, 1),
    checkup_weight DECIMAL(5, 2),
    blood_pressure_systolic INT,
    blood_pressure_diastolic INT,
    fetal_position VARCHAR(100),
    fetal_heart_beat INT,
    fetal_heart_tone VARCHAR(100),
    td_vaccine_dose VARCHAR(50),
    edema VARCHAR(10) DEFAULT 'none' CHECK (edema IN ('none', 'mild', 'moderate', 'severe')),
    remarks TEXT,
    checkup_datetime TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    next_schedule DATE
);
CREATE TABLE ultrasounds (
    ultrasound_id BIGSERIAL PRIMARY KEY,
    pregnancy_id BIGINT NOT NULL REFERENCES pregnancies(pregnancy_id) ON DELETE CASCADE,
    ultrasound_date DATE NOT NULL,
    ultrasound_location VARCHAR(255),
    ultrasound_image TEXT,
    remarks TEXT,
    health_worker_name VARCHAR(255),
    health_worker_institution VARCHAR(255),
    health_worker_profession VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE lab_tests (
    lab_test_id BIGSERIAL PRIMARY KEY,
    pregnancy_id BIGINT NOT NULL REFERENCES pregnancies(pregnancy_id) ON DELETE CASCADE,
    lab_test_type VARCHAR(255),
    lab_test_date DATE,
    lab_test_location VARCHAR(255),
    lab_test_image TEXT,
    remarks TEXT,
    health_worker_name VARCHAR(255),
    health_worker_institution VARCHAR(255),
    health_worker_profession VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE deliveries (
    delivery_id BIGSERIAL PRIMARY KEY,
    pregnancy_id BIGINT NOT NULL UNIQUE REFERENCES pregnancies(pregnancy_id) ON DELETE CASCADE,
    delivery_date DATE,
    is_delivery_date_estimated BOOLEAN DEFAULT FALSE,
    place_of_delivery VARCHAR(255),
    delivery_method VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
-- =========================
-- CHILD & IMMUNIZATION
-- =========================
CREATE TABLE children (
    child_id BIGSERIAL PRIMARY KEY,
    mother_id BIGINT NOT NULL REFERENCES mothers(mother_id) ON DELETE CASCADE,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    middle_name VARCHAR(100),
    extension_name VARCHAR(20),
    sex VARCHAR(10) CHECK (sex IN ('male', 'female')),
    added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE birth_details (
    birth_details_id BIGSERIAL PRIMARY KEY,
    child_id BIGINT NOT NULL UNIQUE REFERENCES children(child_id) ON DELETE CASCADE,
    birthdate DATE,
    birth_weight DECIMAL(5, 2),
    birth VARCHAR(255),
    birthplace_city_municipality VARCHAR(255),
    birthplace_province VARCHAR(255),
    birth_length DECIMAL(5, 2),
    head_circumference DECIMAL(5, 2),
    birth_complications TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE child_details (
    child_details_id BIGSERIAL PRIMARY KEY,
    child_id BIGINT NOT NULL REFERENCES children(child_id) ON DELETE CASCADE,
    child_height DECIMAL(5, 2),
    child_weight DECIMAL(5, 2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE vaccines (
    vaccine_id BIGSERIAL PRIMARY KEY,
    vaccine_name VARCHAR(255) NOT NULL,
    dose_number INT NOT NULL,
    recommended_age_months DECIMAL(4, 1) NOT NULL,
    target_recipients VARCHAR(10) NOT NULL CHECK (target_recipients IN ('child', 'mother')),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (vaccine_name, dose_number)
);
CREATE TABLE immunization_schedule (
    immunization_schedule_id BIGSERIAL PRIMARY KEY,
    bhc_id BIGINT NOT NULL REFERENCES bhc(bhc_id) ON DELETE CASCADE,
    vaccine_id BIGINT NOT NULL REFERENCES vaccines(vaccine_id) ON DELETE CASCADE,
    schedule_date DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (bhc_id, vaccine_id, schedule_date)
);
CREATE TABLE immunization_record (
    immunization_record_id BIGSERIAL PRIMARY KEY,
    child_id BIGINT NOT NULL REFERENCES children(child_id) ON DELETE CASCADE,
    vaccine_id BIGINT NOT NULL REFERENCES vaccines(vaccine_id) ON DELETE CASCADE,
    vaccination_date DATE NOT NULL,
    remarks TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (child_id, vaccine_id)
);
-- =========================
-- ADDITIONAL TABLES
-- =========================
CREATE TABLE checkup_schedule (
    schedule_id BIGSERIAL PRIMARY KEY,
    mother_id BIGINT NOT NULL REFERENCES mothers(mother_id) ON DELETE CASCADE,
    scheduled_date DATE NOT NULL,
    status VARCHAR(20) DEFAULT 'scheduled' CHECK (
        status IN ('scheduled', 'completed', 'missed', 'cancelled')
    ),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE mother_medications (
    mother_medication_id BIGSERIAL PRIMARY KEY,
    mother_id BIGINT NOT NULL REFERENCES mothers(mother_id) ON DELETE CASCADE,
    mother_medication_name VARCHAR(255) NOT NULL,
    frequency VARCHAR(100),
    quantity INT,
    start_date DATE,
    end_date DATE,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'completed', 'stopped')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE given_medications (
    given_medication_id BIGSERIAL PRIMARY KEY,
    mother_id BIGINT NOT NULL REFERENCES mothers(mother_id) ON DELETE CASCADE,
    given_medication_name VARCHAR(255) NOT NULL,
    quantity INT NOT NULL,
    date_given DATE NOT NULL
);
CREATE TABLE journal_entries (
    entry_id BIGSERIAL PRIMARY KEY,
    mother_id BIGINT NOT NULL REFERENCES mothers(mother_id) ON DELETE CASCADE,
    title VARCHAR(255),
    content TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
-- =====================================================
-- AI RESPONSES TABLE
-- Stores all AI-generated insights from different modules
-- =====================================================
CREATE TABLE ai_responses (
    ai_response_id BIGSERIAL PRIMARY KEY,
    -- Unique identifier for each AI-generated response
    response_type VARCHAR(50) NOT NULL,
    -- Type of AI output.
    -- Examples: risk_assessment, checkup_summary, lab_insight,
    -- ultrasound_analysis, growth_analysis, recommendation
    reference_table VARCHAR(50),
    -- Name of the table that the AI analysis is based on.
    -- Examples: ultrasounds, prenatal_checkups, lab_tests,
    -- child_details, pregnancies
    reference_id BIGINT,
    -- ID of the specific record from the reference_table
    -- that the AI analyzed
    ai_model VARCHAR(100),
    -- Name or version of the AI model used
    -- Example: Gemini 1.5, GPT-4, Custom AI model
    confidence_score DECIMAL(5, 2),
    -- Optional confidence score from AI
    -- Example: 0.92 = 92% confidence
    response TEXT NOT NULL,
    -- The full AI-generated explanation, insight,
    -- or recommendation
    response_category VARCHAR(50),
    -- Classification of AI output
    -- Examples: analysis, insight, recommendation, alert
    status VARCHAR(20) DEFAULT 'generated',
    -- Current review status of the AI response
    -- Examples: generated, edited, approved
    generated_by_ai BOOLEAN DEFAULT TRUE,
    -- Indicates if the response was generated by AI
    -- or manually created by a healthcare worker
    approved_by BIGINT REFERENCES accounts(account_id),
    -- Account ID of the midwife or admin who approved the AI output
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    -- Timestamp when the AI response was generated
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP -- Timestamp when the AI response was last updated
);
-- =====================================================
-- AI EDIT HISTORY
-- Tracks edits made to AI responses for transparency
-- =====================================================
CREATE TABLE ai_edit_history (
    ai_edit_history_id BIGSERIAL PRIMARY KEY,
    -- Unique identifier for each edit record
    ai_response_id BIGINT NOT NULL REFERENCES ai_responses(ai_response_id) ON DELETE CASCADE,
    -- The AI response that was edited
    old_content TEXT,
    -- Original AI-generated content before editing
    new_content TEXT,
    -- Updated content after editing
    edited_by BIGINT REFERENCES accounts(account_id),
    -- Account ID of the user who edited the response
    edit_reason TEXT,
    -- Optional explanation of why the AI output was edited
    -- Example: AI misinterpreted fetal heart rate
    edited_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP -- Timestamp when the edit occurred
);
-- =====================================================
-- PREGNANCY RISK ASSESSMENTS
-- Stores overall pregnancy risk classification
-- =====================================================
CREATE TABLE pregnancy_risk_assessments (
    pregnancy_risk_id BIGSERIAL PRIMARY KEY,
    -- Unique identifier for each pregnancy risk evaluation
    pregnancy_id BIGINT NOT NULL REFERENCES pregnancies(pregnancy_id) ON DELETE CASCADE,
    -- The pregnancy being evaluated
    ai_response_id BIGINT REFERENCES ai_responses(ai_response_id),
    -- Links the risk assessment to the AI response
    -- that generated the evaluation
    risk_level VARCHAR(10),
    -- Overall pregnancy risk level
    -- Examples: low, medium, high
    assessed_by_ai BOOLEAN DEFAULT TRUE,
    -- Indicates if the risk was generated by AI
    -- or manually evaluated by a midwife
    reviewed_by BIGINT REFERENCES accounts(account_id),
    -- Midwife or healthcare worker who reviewed
    -- or confirmed the AI-generated risk
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    -- Timestamp when the risk assessment was created
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP -- Timestamp when the risk assessment was last updated
);
-- =====================================================
-- PREGNANCY RISK FACTORS
-- Stores individual risk factors contributing to pregnancy risk
-- =====================================================
CREATE TABLE pregnancy_risk_factors (
    risk_factor_id BIGSERIAL PRIMARY KEY,
    -- Unique identifier for each risk factor
    pregnancy_risk_id BIGINT NOT NULL REFERENCES pregnancy_risk_assessments(pregnancy_risk_id) ON DELETE CASCADE,
    -- The pregnancy risk assessment this factor belongs to
    factor VARCHAR(255) NOT NULL,
    -- Description of the detected risk factor
    -- Example: High Blood Pressure, Low Fetal Heart Rate
    risk_influence VARCHAR(10),
    -- Level of influence this factor contributes to the overall risk
    -- Examples: low, medium, high
    source_table VARCHAR(50),
    -- Table where the factor originated
    -- Examples: prenatal_checkups, ultrasounds, lab_tests
    source_id BIGINT,
    -- Specific record ID in the source_table
    -- Example: prenatal_checkup_id or ultrasound_id
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP -- Timestamp when the risk factor was recorded
);
-- =====================================================
-- AI PROMPT LOGS
-- Stores prompts sent to the AI model for transparency
-- and reproducibility of AI-generated insights
-- =====================================================
CREATE TABLE ai_prompt_logs (
    prompt_log_id BIGSERIAL PRIMARY KEY,
    -- Unique identifier for each prompt record
    ai_response_id BIGINT REFERENCES ai_responses(ai_response_id),
    -- AI response generated from this prompt
    prompt TEXT,
    -- The full prompt sent to the AI model
    model_used VARCHAR(100),
    -- AI model used to generate the response
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP -- Timestamp when the AI prompt was executed
);
CREATE TABLE files (
    file_id BIGSERIAL PRIMARY KEY,
    -- Unique identifier for each uploaded file
    bucket_name VARCHAR(100) NOT NULL,
    -- Supabase storage bucket name
    -- Example: ultrasounds, lab-tests, child-growth, profile-photos
    file_path TEXT NOT NULL,
    -- Path inside the bucket
    -- Example: ultrasounds/12/scan_171991234.png
    file_name VARCHAR(255),
    -- Original uploaded file name
    file_category VARCHAR(50),
    -- Logical file category
    -- Examples: ultrasound_image, lab_result_image, growth_chart, profile_photo
    mime_type VARCHAR(100),
    -- File MIME type
    -- Example: image/png, image/jpeg, application/pdf
    file_size BIGINT,
    -- File size in bytes
    uploaded_by BIGINT REFERENCES accounts(account_id) ON DELETE
    SET NULL,
        -- Account that uploaded the file
        reference_type VARCHAR(50),
        -- Logical reference type
        -- Examples: ultrasound, lab_test, child, account
        reference_id BIGINT,
        -- ID of the referenced record
        processing_type VARCHAR(50),
        -- Defines what processing should be applied to this file
        -- Examples:
        -- mother_registration
        -- child_registration
        -- lab_test
        -- ultrasound_analysis
        -- profile_photo
        ai_processed BOOLEAN DEFAULT FALSE,
        -- Indicates whether the file has been analyzed by AI
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE ocr_results (
    ocr_result_id BIGSERIAL PRIMARY KEY,
    -- Unique OCR result record
    file_id BIGINT NOT NULL REFERENCES files(file_id) ON DELETE CASCADE,
    -- File that was processed with OCR
    extracted_text TEXT,
    -- Raw OCR text extracted from the image
    structured_data JSONB,
    -- Structured OCR data
    -- Example JSON:
    -- {
    --   "glucose": 135,
    --   "hemoglobin": 11.2
    -- }
    processed_by_ai BOOLEAN DEFAULT TRUE,
    -- Indicates whether OCR was performed by AI (Gemini)
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
-- =========================
-- CREATE INDEXES FOR PERFORMANCE
-- =========================
CREATE INDEX idx_accounts_email ON accounts(email_address);
CREATE INDEX idx_accounts_type ON accounts(account_type);
CREATE INDEX idx_mothers_account ON mothers(account_id);
CREATE INDEX idx_mothers_bhc ON mothers(assigned_bhc_id);
CREATE INDEX idx_pregnancies_mother ON pregnancies(mother_id);
CREATE INDEX idx_pregnancies_status ON pregnancies(status);
CREATE INDEX idx_children_mother ON children(mother_id);
CREATE INDEX idx_prenatal_pregnancy ON prenatal_checkups(pregnancy_id);
CREATE INDEX idx_immunization_child ON immunization_record(child_id);
CREATE INDEX idx_checkup_schedule_mother ON checkup_schedule(mother_id);
CREATE INDEX idx_checkup_schedule_date ON checkup_schedule(scheduled_date);
CREATE INDEX idx_files_reference ON files(reference_type, reference_id);
CREATE INDEX idx_ocr_file ON ocr_results(file_id);
CREATE INDEX idx_ai_reference ON ai_responses(reference_table, reference_id);
-- =========================
-- UPDATED_AT TRIGGERS
-- =========================
CREATE OR REPLACE FUNCTION update_updated_at_column() RETURNS TRIGGER AS $$ BEGIN NEW.updated_at = CURRENT_TIMESTAMP;
RETURN NEW;
END;
$$ language 'plpgsql';
DROP TRIGGER IF EXISTS update_accounts_updated_at ON accounts;
CREATE TRIGGER update_accounts_updated_at BEFORE
UPDATE ON accounts FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
DROP TRIGGER IF EXISTS update_emergency_contacts_updated_at ON emergency_contacts;
CREATE TRIGGER update_emergency_contacts_updated_at BEFORE
UPDATE ON emergency_contacts FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
DROP TRIGGER IF EXISTS update_allergies_updated_at ON allergies;
CREATE TRIGGER update_allergies_updated_at BEFORE
UPDATE ON allergies FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
DROP TRIGGER IF EXISTS update_child_details_updated_at ON child_details;
CREATE TRIGGER update_child_details_updated_at BEFORE
UPDATE ON child_details FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
DROP TRIGGER IF EXISTS update_checkup_schedule_updated_at ON checkup_schedule;
CREATE TRIGGER update_checkup_schedule_updated_at BEFORE
UPDATE ON checkup_schedule FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
DROP TRIGGER IF EXISTS update_journal_entries_updated_at ON journal_entries;
CREATE TRIGGER update_journal_entries_updated_at BEFORE
UPDATE ON journal_entries FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
DROP TRIGGER IF EXISTS update_ai_responses_updated_at ON ai_responses;
CREATE TRIGGER update_ai_responses_updated_at BEFORE
UPDATE ON ai_responses FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
DROP TRIGGER IF EXISTS update_pregnancy_risk_assessments_updated_at ON pregnancy_risk_assessments;
CREATE TRIGGER update_pregnancy_risk_assessments_updated_at BEFORE
UPDATE ON pregnancy_risk_assessments FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();