💉 VACCINE SEED DATA (PH EPI – ALIGNED) -- =====================================================
-- SEED DATA: VACCINES
-- INAAGAPAY SADD SYSTEM
-- =====================================================
INSERT INTO vaccines (
        vaccine_name,
        dose_number,
        recommended_age_months,
        target_recipients,
        notes
    )
VALUES -- =========================
    -- AT BIRTH
    -- =========================
    (
        'BCG',
        1,
        0,
        'child',
        'Protection against tuberculosis'
    ),
    (
        'Hepatitis B',
        1,
        0,
        'child',
        'Birth dose; prevent mother-to-child transmission'
    ),
    -- =========================
    -- 6 WEEKS (1.5 MONTHS)
    -- =========================
    ('Pentavalent', 1, 1.5, 'child', 'DPT-HepB-Hib'),
    (
        'Oral Polio Vaccine',
        1,
        1.5,
        'child',
        'OPV Dose 1'
    ),
    (
        'Inactivated Polio Vaccine',
        1,
        1.5,
        'child',
        'IPV Dose 1'
    ),
    (
        'Pneumococcal Conjugate Vaccine',
        1,
        1.5,
        'child',
        'PCV Dose 1'
    ),
    ('Rotavirus', 1, 1.5, 'child', 'Rotavirus Dose 1'),
    -- =========================
    -- 10 WEEKS (2.5 MONTHS)
    -- =========================
    ('Pentavalent', 2, 2.5, 'child', 'DPT-HepB-Hib'),
    (
        'Oral Polio Vaccine',
        2,
        2.5,
        'child',
        'OPV Dose 2'
    ),
    (
        'Pneumococcal Conjugate Vaccine',
        2,
        2.5,
        'child',
        'PCV Dose 2'
    ),
    ('Rotavirus', 2, 2.5, 'child', 'Rotavirus Dose 2'),
    -- =========================
    -- 14 WEEKS (3.5 MONTHS)
    -- =========================
    ('Pentavalent', 3, 3.5, 'child', 'DPT-HepB-Hib'),
    (
        'Oral Polio Vaccine',
        3,
        3.5,
        'child',
        'OPV Dose 3'
    ),
    (
        'Inactivated Polio Vaccine',
        2,
        3.5,
        'child',
        'IPV Dose 2'
    ),
    (
        'Pneumococcal Conjugate Vaccine',
        3,
        3.5,
        'child',
        'PCV Dose 3'
    ),
    -- =========================
    -- 9 MONTHS
    -- =========================
    (
        'Measles, Mumps, Rubella',
        1,
        9,
        'child',
        'MMR Dose 1'
    ),
    -- =========================
    -- 12 MONTHS
    -- =========================
    (
        'Measles, Mumps, Rubella',
        2,
        12,
        'child',
        'MMR Dose 2'
    ),
    -- =========================
    -- MATERNAL VACCINES
    -- =========================
    (
        'Tetanus-Diphtheria',
        1,
        0,
        'mother',
        'Td/TT Dose 1 during pregnancy'
    ),
    (
        'Tetanus-Diphtheria',
        2,
        1,
        'mother',
        'Td/TT Dose 2'
    ),
    (
        'Tetanus-Diphtheria',
        3,
        6,
        'mother',
        'Td/TT Dose 3'
    ),
    (
        'Tetanus-Diphtheria',
        4,
        12,
        'mother',
        'Td/TT Dose 4'
    ),
    (
        'Tetanus-Diphtheria',
        5,
        24,
        'mother',
        'Td/TT Dose 5'
    );