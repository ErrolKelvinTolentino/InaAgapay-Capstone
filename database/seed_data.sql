-- Seed data for symptom types
INSERT INTO symptom_types (symptom_name, risk_category, description)
VALUES -- ======================
    -- DANGER SIGNS (EMERGENCY)
    -- ======================
    (
        'Vaginal Bleeding',
        'danger',
        'Possible miscarriage or placental complication'
    ),
    ('Convulsions', 'danger', 'Possible eclampsia'),
    (
        'Severe Headache',
        'danger',
        'Possible preeclampsia'
    ),
    (
        'Blurred Vision',
        'danger',
        'Possible preeclampsia'
    ),
    (
        'Severe Abdominal Pain',
        'danger',
        'Possible placental abruption or ectopic pregnancy'
    ),
    (
        'Leaking Vaginal Fluid',
        'danger',
        'Possible premature rupture of membranes'
    ),
    (
        'No Fetal Movement',
        'danger',
        'Possible fetal distress or fetal death'
    ),
    (
        'Difficulty Breathing',
        'danger',
        'Possible cardiopulmonary complication'
    ),
    (
        'High Fever',
        'danger',
        'Possible maternal infection'
    ),
    (
        'Severe Swelling of Face or Hands',
        'danger',
        'Possible preeclampsia'
    ),
    -- ======================
    -- WARNING SIGNS (MONITOR CLOSELY)
    -- ======================
    (
        'Reduced Fetal Movement',
        'warning',
        'Possible fetal distress'
    ),
    (
        'Persistent Vomiting',
        'warning',
        'Possible hyperemesis gravidarum'
    ),
    (
        'Painful Urination',
        'warning',
        'Possible urinary tract infection'
    ),
    (
        'Pelvic Pain',
        'warning',
        'Possible infection or ligament strain'
    ),
    (
        'Severe Itching',
        'warning',
        'Possible intrahepatic cholestasis'
    ),
    (
        'Dizziness',
        'warning',
        'Possible anemia or hypotension'
    ),
    (
        'Chest Pain',
        'warning',
        'Possible cardiovascular complication'
    ),
    (
        'Moderate Swelling',
        'warning',
        'May indicate developing preeclampsia'
    ),
    -- ======================
    -- NORMAL PREGNANCY SYMPTOMS
    -- ======================
    (
        'Back Pain',
        'normal',
        'Common musculoskeletal discomfort during pregnancy'
    ),
    (
        'Nausea',
        'normal',
        'Morning sickness due to hormonal changes'
    ),
    (
        'Vomiting',
        'normal',
        'Common early pregnancy symptom'
    ),
    (
        'Fatigue',
        'normal',
        'Hormonal and metabolic changes during pregnancy'
    ),
    (
        'Frequent Urination',
        'normal',
        'Pressure from the uterus on the bladder'
    ),
    (
        'Heartburn',
        'normal',
        'Gastroesophageal reflux due to pregnancy hormones'
    ),
    (
        'Constipation',
        'normal',
        'Hormonal digestion changes'
    ),
    (
        'Skin Rash',
        'normal',
        'Hormonal skin reactions during pregnancy'
    );