INAAGAPAY SADD DATABASE -- =====================================================
-- DATABASE: Maternal & Child Health Information System
-- MySQL 8+
-- =====================================================
SET FOREIGN_KEY_CHECKS = 0;
-- =========================
-- ACCOUNTS & SECURITY
-- =========================
CREATE TABLE accounts (
    account_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    email_address VARCHAR(255) NULL UNIQUE,
    password_hash VARCHAR(255) NULL,
    account_type ENUM('admin', 'midwife', 'mother') NOT NULL,
    first_name VARCHAR(100) NULL,
    middle_name VARCHAR(100) NULL,
    last_name VARCHAR(100) NULL,
    extension_name VARCHAR(100) NULL,
    phone_number VARCHAR(20) NULL,
    verification_code VARCHAR(100) NULL,
    verification_expires DATETIME NULL,
    is_verified BOOLEAN DEFAULT FALSE,
    status ENUM('active', 'inactive', 'suspended') DEFAULT 'active',
    reset_code VARCHAR(6) NULL,
    reset_expires DATETIME NULL,
    last_login_token VARCHAR(128) NULL,
    last_login_at DATETIME NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATECURRENT_TIMESTAMP
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = 'System user accounts';
CREATE TABLE password_history (
    pass_history_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    account_id BIGINT NOT NULL,
    password VARCHAR(255) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    replaced_at DATETIME,
    FOREIGN KEY (account_id) REFERENCES accounts(account_id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = 'Password change history';
CREATE TABLE audit_trail (
    audit_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    account_id BIGINT,
    action VARCHAR(100) NOT NULL,
    table_name VARCHAR(100),
    old_data JSON,
    new_data JSON,
    description TEXT,
    action_timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    ip_address VARCHAR(45),
    FOREIGN KEY (account_id) REFERENCES accounts(account_id) ON DELETE
    SET NULL
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = 'Audit logging';
-- =========================
-- BARANGAY & STAFF
-- =========================
CREATE TABLE bhc (
    bhc_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    bhc_name VARCHAR(255) NOT NULL
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = 'Barangay Health Centers';
CREATE TABLE midwives (
    midwife_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    account_id BIGINT NOT NULL UNIQUE,
    assigned_bhc_id BIGINT NOT NULL,
    FOREIGN KEY (account_id) REFERENCES accounts(account_id) ON DELETE CASCADE,
    FOREIGN KEY (assigned_bhc_id) REFERENCES bhc(bhc_id) ON DELETE RESTRICT
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = 'Midwives';
-- =========================
-- MOTHERS & MEDICAL PROFILE
-- =========================
CREATE TABLE mothers (
    mother_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    account_id BIGINT NOT NULL UNIQUE,
    assigned_bhc_id BIGINT NULL,
    birthdate DATE,
    house_number VARCHAR(50),
    street VARCHAR(100),
    barangay VARCHAR(100),
    city_municipality VARCHAR(100),
    province VARCHAR(100),
    status ENUM('active', 'inactive') DEFAULT 'active',
    height DECIMAL(5, 2),
    weight DECIMAL(5, 2),
    blood_type VARCHAR(100),
    FOREIGN KEY (account_id) REFERENCES accounts(account_id),
    FOREIGN KEY (assigned_bhc_id) REFERENCES bhc(bhc_id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = 'Mother profiles';
COMMENT = 'Emergency contacts';
CREATE TABLE emergency_contacts (
    emergency_contact_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    mother_id BIGINT NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    middle_name VARCHAR(100),
    extension_name VARCHAR(20),
    phone_number VARCHAR(20),
    affiliation VARCHAR(100) NULL,
    email_address VARCHAR(255),
    house_number VARCHAR(50),
    street VARCHAR(100),
    barangay VARCHAR(100),
    city_municipality VARCHAR(100),
    province VARCHAR(100),
    status ENUM('active', 'inactive') DEFAULT 'active',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (mother_id) REFERENCES mothers(mother_id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 CREATE TABLE medical_conditions (
    med_condition_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    mother_id BIGINT NOT NULL,
    condition_name VARCHAR(255) NOT NULL,
    diagnosis_date DATE,
    status ENUM('active', 'resolved') DEFAULT 'active',
    remarks TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (mother_id) REFERENCES mothers(mother_id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = 'Medical conditions';
CREATE TABLE allergies (
    allergy_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    mother_id BIGINT NOT NULL,
    allergen VARCHAR(255) NOT NULL,
    diagnosis_date DATE,
    status ENUM('active', 'resolved') DEFAULT 'active',
    treatment TEXT,
    remarks TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (mother_id) REFERENCES mothers(mother_id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = 'Allergies';
-- =========================
-- PREGNANCY & CARE
-- =========================
CREATE TABLE pregnancies (
    pregnancy_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    mother_id BIGINT NOT NULL,
    pregnancy_risk_level ENUM('low', 'medium', 'high'),
    last_menstrual_period DATE,
    expected_date_of_delivery DATE,
    status ENUM('ongoing', 'ended') NOT NULL,
    outcome ENUM(
        'live_birth',
        'stillbirth',
        'miscarriage',
        'abortion',
        'ectopic'
    ),
    outcome_date DATE,
    is_outcome_date_estimated BOOLEAN DEFAULT FALSE,
    gestational_age_at_end DECIMAL(4, 1),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    ended_at DATETIME,
    FOREIGN KEY (mother_id) REFERENCES mothers(mother_id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = 'Pregnancy records';
CREATE TABLE prenatal_checkups (
    prenatal_checkup_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    pregnancy_id BIGINT NOT NULL,
    midwife_id BIGINT NOT NULL,
    age_of_gestation DECIMAL(4, 1),
    checkup_weight DECIMAL(5, 2),
    blood_pressure_systolic INT,
    blood_pressure_diastolic INT,
    fetal_position VARCHAR(100),
    fetal_heart_beat INT,
    fetal_heart_tone VARCHAR(100),
    td_vaccine_dose VARCHAR(50),
    edema ENUM('none', 'mild', 'moderate', 'severe') DEFAULT 'none',
    remarks TEXT,
    checkup_datetime TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    next_schedule DATE,
    FOREIGN KEY (pregnancy_id) REFERENCES pregnancies(pregnancy_id) ON DELETE CASCADE,
    FOREIGN KEY (midwife_id) REFERENCES midwives(midwife_id) ON DELETE RESTRICT
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = 'Prenatal checkups';
CREATE TABLE ultrasounds (
    ultrasound_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    pregnancy_id BIGINT NOT NULL,
    ultrasound_date DATE NOT NULL,
    ultrasound_location VARCHAR(255),
    ultrasound_image TEXT,
    remarks TEXT,
    health_worker_name VARCHAR(255),
    health_worker_institution VARCHAR(255),
    health_worker_profession VARCHAR(100),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (pregnancy_id) REFERENCES pregnancies(pregnancy_id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = 'Ultrasound records';
CREATE TABLE lab_tests (
    lab_test_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    pregnancy_id BIGINT NOT NULL,
    lab_test_type VARCHAR(255),
    lab_test_date DATE,
    lab_test_location VARCHAR(255),
    lab_test_image TEXT,
    remarks TEXT,
    health_worker_name VARCHAR(255),
    health_worker_institution VARCHAR(255),
    health_worker_profession VARCHAR(100),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (pregnancy_id) REFERENCES pregnancies(pregnancy_id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = 'Laboratory tests';
CREATE TABLE deliveries (
    delivery_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    pregnancy_id BIGINT NOT NULL UNIQUE,
    delivery_date DATE,
    is_delivery_date_estimated BOOLEAN DEFAULT FALSE,
    place_of_delivery VARCHAR(255),
    delivery_method VARCHAR (255),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (pregnancy_id) REFERENCES pregnancies(pregnancy_id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = 'Delivery details';
-- =========================
-- CHILD & IMMUNIZATION
-- =========================
CREATE TABLE children (
    child_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    mother_id BIGINT NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    middle_name VARCHAR(100),
    extension_name VARCHAR(20),
    sex ENUM('male', 'female'),
    added_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (mother_id) REFERENCES mothers(mother_id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = 'Children';
CREATE TABLE birth_details (
    birth_details_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    child_id BIGINT NOT NULL UNIQUE,
    birthdate DATE,
    birth_weight DECIMAL(5, 2),
    birth VARCHAR(255),
    birthplace_city_municipality VARCHAR(255),
    birthplace_province VARCHAR(255),
    birth_length DECIMAL(5, 2),
    head_circumference DECIMAL(5, 2),
    birth_complications TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (child_id) REFERENCES children(child_id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = 'Birth details';
CREATE TABLE child_details (
    child_details_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    child_id BIGINT NOT NULL,
    child_height DECIMAL(5, 2),
    child_weight DECIMAL(5, 2),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (child_id) REFERENCES children(child_id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = 'Child growth records';
CREATE TABLE vaccines (
    vaccine_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    vaccine_name VARCHAR(255) NOT NULL,
    dose_number INT NOT NULL,
    recommended_age_months DECIMAL(4, 1) NOT NULL,
    target_recipients ENUM('child', 'mother') NOT NULL,
    notes TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (vaccine_name, dose_number)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = 'Vaccine dose definitions';
CREATE TABLE immunization_schedule (
    immunization_schedule_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    bhc_id BIGINT NOT NULL,
    vaccine_id BIGINT NOT NULL,
    schedule_date DATE NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (bhc_id) REFERENCES bhc(bhc_id) ON DELETE CASCADE,
    FOREIGN KEY (vaccine_id) REFERENCES vaccines(vaccine_id) ON DELETE CASCADE,
    UNIQUE (bhc_id, vaccine_id, schedule_date)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = 'Barangay immunization schedules';
CREATE TABLE immunization_record (
    immunization_record_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    child_id BIGINT NOT NULL,
    vaccine_id BIGINT NOT NULL,
    vaccination_date DATE NOT NULL,
    remarks TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (child_id) REFERENCES children(child_id) ON DELETE CASCADE,
    FOREIGN KEY (vaccine_id) REFERENCES vaccines(vaccine_id) ON DELETE CASCADE,
    UNIQUE (child_id, vaccine_id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = 'Administered vaccines';
SET FOREIGN_KEY_CHECKS = 1;
-- =====================================================
-- ADDITIONAL TABLES (MISSED ON FIRST PASS)
-- =====================================================
-- -------------------------
-- CHECKUP SCHEDULE (PLANNED VISITS)
-- -------------------------
CREATE TABLE checkup_schedule (
    schedule_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    mother_id BIGINT NOT NULL,
    scheduled_date DATE NOT NULL,
    status ENUM('scheduled', 'completed', 'missed', 'cancelled') DEFAULT 'scheduled',
    notes TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_checkup_schedule_mother FOREIGN KEY (mother_id) REFERENCES mothers(mother_id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = 'Planned maternal checkup schedules';
-- -------------------------
-- MOTHER MEDICATIONS (PRESCRIBED / ADVISED)
-- -------------------------
CREATE TABLE mother_medications (
    mother_medication_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    mother_id BIGINT NOT NULL,
    mother_medication_name VARCHAR(255) NOT NULL,
    frequency VARCHAR(100),
    quantity INT,
    start_date DATE,
    end_date DATE,
    status ENUM('active', 'completed', 'stopped') DEFAULT 'active',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_mother_medication_mother FOREIGN KEY (mother_id) REFERENCES mothers(mother_id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = 'Medications and supplements prescribed to mothers';
-- -------------------------
-- GIVEN MEDICATIONS (ACTUAL DISPENSING)
-- -------------------------
CREATE TABLE given_medications (
    given_medication_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    mother_id BIGINT NOT NULL,
    given_medication_name VARCHAR(255) NOT NULL,
    quantity INT NOT NULL,
    date_given DATE NOT NULL,
    CONSTRAINT fk_given_medication_plan FOREIGN KEY (mother_id) REFERENCES mothers(mother_id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = 'Actual medication doses given to mothers';
-- -------------------------
-- JOURNAL ENTRIES (NOTES / OBSERVATIONS)
-- -------------------------
CREATE TABLE journal_entries (
    entry_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    mother_id BIGINT NOT NULL,
    title VARCHAR(255),
    content TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_journal_mother FOREIGN KEY (mother_id) REFERENCES mothers(mother_id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = 'Free-form notes and journal entries for mothers';