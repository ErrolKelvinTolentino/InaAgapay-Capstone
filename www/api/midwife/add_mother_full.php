<?php
require_once __DIR__ . '/../db.php';

// swallow auth output (safety for JSON payloads)
ob_start();
require_once __DIR__ . '/../auth/auth_check.php';
ob_end_clean();

header('Content-Type: application/json');

function expect(bool $condition, string $message): void
{
    if (!$condition) {
        throw new Exception($message);
    }
}

function fmtDate(?string $value): ?string
{
    if (empty($value))
        return null;
    return date('Y-m-d', strtotime($value));
}


function fmtDateTime(?string $value): ?string
{
    if (empty($value)) {
        return null;
    }
    return date('Y-m-d H:i:s', strtotime($value));
}
function weeksBetween(?string $start, ?string $end): ?float
{
    if (!$start || !$end)
        return null;
    $s = new DateTime($start);
    $e = new DateTime($end);
    $days = (int) $s->diff($e)->format('%r%a');
    return round($days / 7, 1);
}

function computeRisk(array $input, array $profile, array $conditions, array $allergies): array
{
    $score = 0;
    $factors = [];

    $add = function (string $label, int $points) use (&$score, &$factors) {
        $factors[] = ['label' => $label, 'points' => $points];
        $score += $points;
    };

    // Age
    if (!empty($profile['birthdate'])) {
        $b = new DateTime($profile['birthdate']);
        $now = new DateTime();
        $age = $now->diff($b)->y;
        if ($age < 18)
            $add('Young maternal age (<18)', 2);
        elseif ($age >= 35)
            $add('Advanced maternal age (≥35)', 2);
    }

    // BMI
    if (!empty($profile['height']) && !empty($profile['weight']) && $profile['height'] > 0) {
        $bmi = $profile['weight'] / pow($profile['height'] / 100, 2);
        if ($bmi < 18.5)
            $add('Underweight BMI (<18.5)', 2);
        elseif ($bmi >= 25 && $bmi < 30)
            $add('Overweight BMI (25–29.9)', 1);
        elseif ($bmi >= 30)
            $add('Obese BMI (≥30)', 2);
    }

    // Medical conditions (active)
    $activeCount = 0;
    foreach ($conditions as $cond) {
        if (($cond['status'] ?? 'active') !== 'active')
            continue;
        $activeCount++;
        $name = strtolower($cond['condition_name'] ?? '');
        $points = 1;
        if (strpos($name, 'anemia') !== false)
            $points = 2;
        elseif (strpos($name, 'diabetes') !== false)
            $points = 3;
        elseif (strpos($name, 'hypertension') !== false)
            $points = 3;
        elseif (strpos($name, 'asthma') !== false)
            $points = 1;
        elseif (strpos($name, 'smoking') !== false)
            $points = 2;
        elseif (strpos($name, 'alcohol') !== false)
            $points = 2;
        elseif (strpos($name, 'domestic') !== false || strpos($name, 'violence') !== false)
            $points = 3;
        elseif (strpos($name, 'other') !== false)
            $points = 1;

        $add(($cond['condition_name'] ?? 'Medical condition') . ' (active)', $points);
    }
    if ($activeCount >= 2) {
        $add('Multiple comorbidities', 1);
    }

    // Allergies
    $hasActiveAllergy = false;
    foreach ($allergies as $allergy) {
        if (($allergy['status'] ?? 'active') === 'active') {
            $hasActiveAllergy = true;
            break;
        }
    }
    if ($hasActiveAllergy) {
        $add('Active allergy reported', 1);
    }

    // Pregnancy history
    $history = $input['pregnancy_history'] ?? [];
    foreach ($history as $p) {
        switch ($p['outcome'] ?? '') {
            case 'miscarriage':
                $add('History of miscarriage', 2);
                break;
            case 'stillbirth':
                $add('History of stillbirth', 3);
                break;
            case 'ectopic':
                $add('History of ectopic pregnancy', 3);
                break;
            case 'abortion':
                $add('History of abortion', 1);
                break;
        }
    }
    $totalPregnancies = count($history) + 1;
    if ($totalPregnancies >= 3) {
        $add('Gravida ≥3 (multiple pregnancies)', 1);
    }

    // Prenatal check factors
    $first = $input['first_prenatal_checkup'] ?? [];
    if (!empty($first)) {
        $sys = (int) ($first['blood_pressure_systolic'] ?? 0);
        $dia = (int) ($first['blood_pressure_diastolic'] ?? 0);
        if ($sys >= 140 || $dia >= 90) {
            $add('Elevated blood pressure (≥140/90)', 3);
        }

        $edema = $first['edema'] ?? 'none';
        if ($edema === 'mild')
            $add('Mild edema', 1);
        elseif ($edema === 'moderate')
            $add('Moderate edema', 2);
        elseif ($edema === 'severe')
            $add('Severe edema', 3);

        $fetalBeat = $first['fetal_heart_beat'] ?? null;
        $beatAbnormal = ($first['abnormal_fetal_heart_beat'] ?? false) ||
            ($fetalBeat !== null && ($fetalBeat < 110 || $fetalBeat > 160));
        if ($beatAbnormal) {
            $add('Abnormal fetal heartbeat', 3);
        }

        $checkDate = $first['checkup_datetime'] ?? $first['checkup_date'] ?? null;
        $checkDateOnly = $checkDate ? date('Y-m-d', strtotime($checkDate)) : null;
        $aog = $first['age_of_gestation'] ?? weeksBetween($input['current_pregnancy']['last_menstrual_period'] ?? null, $checkDateOnly);
        $pos = strtolower($first['fetal_position'] ?? '');
        $posAbnormal = ($first['abnormal_fetal_position'] ?? false) ||
            ($pos !== '' && $pos !== 'cephalic' && $pos !== 'vertex' && $pos !== 'unknown');
        if ($aog !== null && $aog >= 28 && $posAbnormal) {
            $add('Abnormal fetal position (late pregnancy)', 1);
        }

        if ($aog !== null && $aog > 20) {
            $add('First prenatal visit after 20 weeks', 2);
        }

        if (!empty($first['missed_scheduled_checkups'])) {
            $add('Missed scheduled prenatal checkups', 1);
        }
    }

    $level = $score >= 6 ? 'high' : ($score >= 3 ? 'medium' : 'low');
    return [$level, $score];
}

try {
    expect(isset($AUTH_USER['account_type']), 'Unauthorized');
    expect($AUTH_USER['account_type'] === 'midwife', 'Only midwives can add mothers');

    $raw = file_get_contents('php://input');
    $input = json_decode($raw, true);
    expect(is_array($input), 'Invalid JSON payload');

    $includeFirstPrenatal = !array_key_exists('include_first_prenatal', $input) || (bool) $input['include_first_prenatal'];

    // Midwife context
    $ctx = $conn->prepare("SELECT m.midwife_id, m.assigned_bhc_id, b.bhc_name FROM midwives m JOIN bhc b ON b.bhc_id = m.assigned_bhc_id WHERE m.account_id = ? LIMIT 1");
    $authAccountId = $AUTH_USER['account_id'];
    $ctx->bind_param('i', $authAccountId);
    $ctx->execute();
    $ctxRes = $ctx->get_result()->fetch_assoc();
    expect($ctxRes !== null, 'Midwife context not found');
    $midwifeId = (int) $ctxRes['midwife_id'];
    $assignedBhcId = (int) $ctxRes['assigned_bhc_id'];
    $assignedBhcName = $ctxRes['bhc_name'] ?? null;

    $acc = $input['account'] ?? [];
    expect(!empty($acc['first_name']), 'First name is required');
    expect(!empty($acc['last_name']), 'Last name is required');
    expect(!empty($acc['phone_number']), 'Phone number is required');

    $email = $acc['email_address'] ?? null;
    if (empty($email)) {
        $email = 'mother_' . uniqid() . '@inaagapay.local';
    }

    $conn->begin_transaction();

    // Account
    $acct = $conn->prepare("INSERT INTO accounts (email_address, account_type, first_name, middle_name, last_name, extension_name, phone_number, is_verified) VALUES (?, 'mother', ?, ?, ?, ?, ?, 1)");
    if (!$acct) {
        throw new Exception('Prepare failed: ' . $conn->error);
    }
    
    $accFirst = $acc['first_name'] ?? null;
    $accMiddle = $acc['middle_name'] ?? null;
    $accLast = $acc['last_name'] ?? null;
    $accExt = $acc['extension_name'] ?? null;
    $accPhone = $acc['phone_number'] ?? null;
    
    if (!$acct->bind_param(
        'ssssss',
        $email,
        $accFirst,
        $accMiddle,
        $accLast,
        $accExt,
        $accPhone
    )) {
        throw new Exception('Bind param failed: ' . $acct->error);
    }
    
    if (!$acct->execute()) {
        throw new Exception('Execute account insert failed: ' . $acct->error);
    }
    
    $accountId = $conn->insert_id;

    // Mother profile
    $profile = $input['mother_profile'] ?? [];
    $province = $profile['province'] ?? 'Bulacan';
    $city = $profile['city_municipality'] ?? 'Baliwag';
    $barangay = $profile['barangay'] ?? $assignedBhcName;

    $birthdate = $profile['birthdate'] ?? null;
    $houseNumber = $profile['house_number'] ?? null;
    $street = $profile['street'] ?? null;
    $height = $profile['height'] ?? null;
    $weight = $profile['weight'] ?? null;
    $bloodType = $profile['blood_type'] ?? null;

    $motherStmt = $conn->prepare("INSERT INTO mothers (account_id, assigned_bhc_id, birthdate, house_number, street, barangay, city_municipality, province, height, weight, blood_type) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
    $motherStmt->bind_param(
        'iisssssssss',
        $accountId,
        $assignedBhcId,
        $birthdate,
        $houseNumber,
        $street,
        $barangay,
        $city,
        $province,
        $height,
        $weight,
        $bloodType
    );
    $motherStmt->execute();
    $motherId = $conn->insert_id;

    // Emergency contacts
    if (!empty($input['emergency_contacts'])) {
        $ecStmt = $conn->prepare("INSERT INTO emergency_contacts (mother_id, first_name, middle_name, last_name, extension_name, phone_number, email_address, affiliation, house_number, street, barangay, city_municipality, province) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
        foreach ($input['emergency_contacts'] as $ec) {
            if (empty($ec['first_name']) || empty($ec['last_name']) || empty($ec['phone_number'])) {
                continue;
            }
            $ecFirst = $ec['first_name'] ?? null;
            $ecMiddle = $ec['middle_name'] ?? null;
            $ecLast = $ec['last_name'] ?? null;
            $ecExt = $ec['extension_name'] ?? null;
            $ecPhone = $ec['phone_number'] ?? null;
            $ecEmail = $ec['email_address'] ?? null;
            $ecAff = $ec['affiliation'] ?? null;
            $ecHouse = $ec['house_number'] ?? null;
            $ecStreet = $ec['street'] ?? null;
            $ecBarangay = $ec['barangay'] ?? null;
            $ecCity = $ec['city_municipality'] ?? null;
            $ecProvince = $ec['province'] ?? null;
            $ecStmt->bind_param(
                'issssssssssss',
                $motherId,
                $ecFirst,
                $ecMiddle,
                $ecLast,
                $ecExt,
                $ecPhone,
                $ecEmail,
                $ecAff,
                $ecHouse,
                $ecStreet,
                $ecBarangay,
                $ecCity,
                $ecProvince
            );
            $ecStmt->execute();
        }
    }

    // Medical conditions
    if (!empty($input['medical_conditions'])) {
        $medStmt = $conn->prepare("INSERT INTO medical_conditions (mother_id, condition_name, diagnosis_date, status, remarks) VALUES (?, ?, ?, ?, ?)");
        $condName = null;
        $diagDate = null;
        $condStatus = null;
        $condRemarks = null;
        $medStmt->bind_param(
            'issss',
            $motherId,
            $condName,
            $diagDate,
            $condStatus,
            $condRemarks
        );
        foreach ($input['medical_conditions'] as $m) {
            $condName = $m['condition_name'] ?? null;
            $diagDate = fmtDate($m['diagnosis_date'] ?? null);
            $condStatus = $m['status'] ?? 'active';
            $condRemarks = $m['remarks'] ?? null;
            $medStmt->execute();
        }
    }

    // Allergies
    if (!empty($input['allergies'])) {
        $allergyStmt = $conn->prepare("INSERT INTO allergies (mother_id, allergen, diagnosis_date, status, treatment, remarks) VALUES (?, ?, ?, ?, ?, ?)");
        $allergen = null;
        $diagDate = null;
        $allergyStatus = null;
        $treatment = null;
        $remarks = null;
        $allergyStmt->bind_param(
            'isssss',
            $motherId,
            $allergen,
            $diagDate,
            $allergyStatus,
            $treatment,
            $remarks
        );
        foreach ($input['allergies'] as $a) {
            $allergen = $a['allergen'] ?? null;
            $diagDate = fmtDate($a['diagnosis_date'] ?? null);
            $allergyStatus = $a['status'] ?? 'active';
            $treatment = $a['treatment'] ?? null;
            $remarks = $a['remarks'] ?? null;
            $allergyStmt->execute();
        }
    }

    // Pregnancy history (ended)
    if (!empty($input['pregnancy_history'])) {
        $pregStmt = $conn->prepare("INSERT INTO pregnancies (mother_id, pregnancy_risk_level, last_menstrual_period, expected_date_of_delivery, status, outcome, outcome_date, is_outcome_date_estimated, gestational_age_at_end, ended_at) VALUES (?, NULL, NULL, NULL, 'ended', ?, ?, ?, ?, ?)");
        $deliveryStmt = $conn->prepare("INSERT INTO deliveries (pregnancy_id, delivery_date, is_delivery_date_estimated, place_of_delivery, delivery_method) VALUES (?, ?, ?, ?, ?)");
        foreach ($input['pregnancy_history'] as $p) {
            expect(!empty($p['outcome']), 'Outcome is required for ended pregnancies');
            expect(!empty($p['outcome_date']), 'Outcome date is required for ended pregnancies');

            $outcomeDate = fmtDate($p['outcome_date'] ?? null);
            $outcome = $p['outcome'];
            $isEstimated = (int) ($p['is_outcome_date_estimated'] ?? 0);
            $gestAge = isset($p['gestational_age_at_end']) && $p['gestational_age_at_end'] !== ''
                ? (float) $p['gestational_age_at_end']
                : null;
            $pregStmt->bind_param(
                'issids',
                $motherId,
                $outcome,
                $outcomeDate,
                $isEstimated,
                $gestAge,
                $outcomeDate
            );
            $pregStmt->execute();
            $histPregId = $conn->insert_id;

            if (in_array($p['outcome'], ['live_birth', 'stillbirth'])) {
                expect(!empty($p['place_of_delivery']) || !empty($p['delivery_method']), 'Delivery details required for live birth / stillbirth');
                $place = $p['place_of_delivery'] ?? null;
                $method = $p['delivery_method'] ?? null;
                $deliveryStmt->bind_param(
                    'isdss',
                    $histPregId,
                    $outcomeDate,
                    $isEstimated,
                    $place,
                    $method
                );
                $deliveryStmt->execute();
            }
        }
    }

    // Current pregnancy (ongoing)
    $preg = $input['current_pregnancy'] ?? [];
    expect(!empty($preg['last_menstrual_period']), 'LMP is required');
    expect(!empty($preg['expected_date_of_delivery']), 'EDD is required');

    $lmp = fmtDate($preg['last_menstrual_period']);
    $edd = fmtDate($preg['expected_date_of_delivery']);
    $daysDiff = (new DateTime($lmp))->diff(new DateTime($edd))->days;
    expect($daysDiff >= 259 && $daysDiff <= 294, 'EDD must be biologically plausible relative to LMP');

    [$riskLevel] = computeRisk($input, $profile, $input['medical_conditions'] ?? [], $input['allergies'] ?? []);

    $curPregStmt = $conn->prepare("INSERT INTO pregnancies (mother_id, pregnancy_risk_level, last_menstrual_period, expected_date_of_delivery, status) VALUES (?, ?, ?, ?, 'ongoing')");
    $curPregStmt->bind_param('isss', $motherId, $riskLevel, $lmp, $edd);
    $curPregStmt->execute();
    $pregnancyId = $conn->insert_id;

    $prenatalId = null;
    if ($includeFirstPrenatal) {
        // First prenatal checkup (optional when include_first_prenatal is false)
        $first = $input['first_prenatal_checkup'] ?? [];
        $checkupDateTime = fmtDateTime($first['checkup_datetime'] ?? $first['checkup_date'] ?? date('Y-m-d H:i:s'));
        $checkupDateObj = new DateTime($checkupDateTime);
        $createdAt = new DateTime();
        if ($checkupDateObj < $createdAt) {
            $checkupDateTime = $createdAt->format('Y-m-d H:i:s');
        }

        $checkupDateOnly = date('Y-m-d', strtotime($checkupDateTime));
        $ageOfGestation = $first['age_of_gestation'] ?? weeksBetween($lmp, $checkupDateOnly);

        $checkupWeight = $first['checkup_weight'] ?? null;
        $bpSys = $first['blood_pressure_systolic'] ?? null;
        $bpDia = $first['blood_pressure_diastolic'] ?? null;
        $fetalPos = $first['fetal_position'] ?? null;
        $fetalHb = $first['fetal_heart_beat'] ?? null;
        $fetalHt = $first['fetal_heart_tone'] ?? null;
        $tdDose = $first['td_vaccine_dose'] ?? null;
        $edema = $first['edema'] ?? 'none';
        $remarks = $first['remarks'] ?? null;

        $prenatalStmt = $conn->prepare("INSERT INTO prenatal_checkups (pregnancy_id, midwife_id, age_of_gestation, checkup_weight, blood_pressure_systolic, blood_pressure_diastolic, fetal_position, fetal_heart_beat, fetal_heart_tone, td_vaccine_dose, edema, remarks, checkup_datetime) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
        $prenatalStmt->bind_param(
            'iiddiisisssss',
            $pregnancyId,
            $midwifeId,
            $ageOfGestation,
            $checkupWeight,
            $bpSys,
            $bpDia,
            $fetalPos,
            $fetalHb,
            $fetalHt,
            $tdDose,
            $edema,
            $remarks,
            $checkupDateTime
        );
        $prenatalStmt->execute();
        $prenatalId = $conn->insert_id;

        // Medications (plans)
        if (!empty($first['mother_medications'])) {
            $medPlanStmt = $conn->prepare("INSERT INTO mother_medications (mother_id, mother_medication_name, frequency, quantity, start_date, end_date, status) VALUES (?, ?, ?, ?, ?, ?, ?)");
            foreach ($first['mother_medications'] as $m) {
                if (empty($m['mother_medication_name']))
                    continue;
                $medName = $m['mother_medication_name'];
                $medFreq = $m['frequency'] ?? null;
                $medQty = $m['quantity'] ?? null;
                $medStart = fmtDate($m['start_date'] ?? null);
                $medEnd = fmtDate($m['end_date'] ?? null);
                $medStatus = $m['status'] ?? 'active';
                $medPlanStmt->bind_param(
                    'ississs',
                    $motherId,
                    $medName,
                    $medFreq,
                    $medQty,
                    $medStart,
                    $medEnd,
                    $medStatus
                );
                $medPlanStmt->execute();
            }
        }

        // Given medications
        if (!empty($first['given_medications'])) {
            $givenStmt = $conn->prepare("INSERT INTO given_medications (mother_id, given_medication_name, quantity, date_given) VALUES (?, ?, ?, ?)");
            foreach ($first['given_medications'] as $g) {
                if (empty($g['given_medication_name']) || empty($g['quantity']))
                    continue;
                $givenName = $g['given_medication_name'];
                $givenQty = $g['quantity'];
                $givenDate = fmtDate($g['date_given'] ?? date('Y-m-d'));
                $givenStmt->bind_param(
                    'isis',
                    $motherId,
                    $givenName,
                    $givenQty,
                    $givenDate
                );
                $givenStmt->execute();
            }
        }
    }

    $conn->commit();

    echo json_encode([
        'success' => true,
        'mother_id' => $motherId,
        'pregnancy_id' => $pregnancyId,
        'prenatal_checkup_id' => $prenatalId,
        'pregnancy_risk_level' => $riskLevel,
    ]);
} catch (Throwable $e) {
    $conn->rollback();
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage(),
    ]);
}
