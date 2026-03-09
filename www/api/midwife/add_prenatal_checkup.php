<?php
require_once __DIR__ . '/../db.php';

// swallow auth output for JSON safety
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
    if (empty($value)) {
        return null;
    }
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
    if (!$start || !$end) {
        return null;
    }
    $s = new DateTime($start);
    $e = new DateTime($end);
    $days = (int) $s->diff($e)->format('%r%a');
    return round($days / 7, 1);
}

function buildRiskNote(string $level, array $topFactors): string
{
    if (empty($topFactors)) {
        switch ($level) {
            case 'high':
                return 'High risk based on current assessment.';
            case 'medium':
                return 'Medium risk with observed factors.';
            default:
                return 'Low risk based on current assessment.';
        }
    }

    if (count($topFactors) === 1) {
        return ucfirst($level) . ' risk due to ' . $topFactors[0] . '.';
    }
    if (count($topFactors) === 2) {
        return ucfirst($level) . ' risk due to ' . $topFactors[0] . ' and ' . $topFactors[1] . '.';
    }

    return ucfirst($level) . ' risk due to ' . $topFactors[0] . ', ' . $topFactors[1] . ', and ' . $topFactors[2] . '.';
}

function computeRisk(
    array $profile,
    array $conditions,
    array $allergies,
    array $history,
    array $first,
    ?string $lmp,
    ?string $checkupDate
): array {
    $score = 0;
    $factors = [];
    $add = function (int $points, string $reason) use (&$score, &$factors) {
        $score += $points;
        $factors[] = $reason;
    };

    // Age
    if (!empty($profile['birthdate'])) {
        $b = new DateTime($profile['birthdate']);
        $now = new DateTime();
        $age = $now->diff($b)->y;
        if ($age < 18) {
            $add(2, 'Teenage pregnancy');
        } elseif ($age >= 35) {
            $add(2, 'Advanced maternal age');
        }
    }

    // BMI
    if (!empty($profile['height']) && !empty($profile['weight']) && $profile['height'] > 0) {
        $bmi = $profile['weight'] / pow($profile['height'] / 100, 2);
        if ($bmi < 18.5) {
            $add(2, 'Underweight (BMI < 18.5)');
        } elseif ($bmi >= 25 && $bmi < 30) {
            $add(1, 'Overweight (BMI 25–29.9)');
        } elseif ($bmi >= 30) {
            $add(2, 'Obese (BMI ≥ 30)');
        }
    }

    // Medical conditions (active)
    $activeCount = 0;
    foreach ($conditions as $cond) {
        if (($cond['status'] ?? 'active') !== 'active') {
            continue;
        }
        $activeCount++;
        $name = strtolower($cond['condition_name'] ?? '');
        if (strpos($name, 'anemia') !== false) {
            $add(2, 'Anemia');
        } elseif (strpos($name, 'diabetes') !== false) {
            $add(3, 'Diabetes');
        } elseif (strpos($name, 'hypertension') !== false) {
            $add(3, 'Hypertension');
        } elseif (strpos($name, 'asthma') !== false) {
            $add(1, 'Asthma');
        } elseif (strpos($name, 'smoking') !== false) {
            $add(2, 'Smoking');
        } elseif (strpos($name, 'alcohol') !== false) {
            $add(2, 'Alcohol use');
        } elseif (strpos($name, 'domestic') !== false || strpos($name, 'violence') !== false) {
            $add(3, 'Domestic violence');
        } else {
            $add(1, 'Other medical condition');
        }
    }
    if ($activeCount >= 2) {
        $add(1, 'Multiple comorbidities');
    }

    // Allergies
    foreach ($allergies as $allergy) {
        if (($allergy['status'] ?? 'active') === 'active') {
            $add(1, 'Active allergy');
            break;
        }
    }

    // Pregnancy history
    foreach ($history as $p) {
        switch ($p['outcome'] ?? '') {
            case 'miscarriage':
                $add(2, 'Previous miscarriage');
                break;
            case 'stillbirth':
                $add(3, 'Previous stillbirth');
                break;
            case 'ectopic':
                $add(3, 'Previous ectopic pregnancy');
                break;
            case 'abortion':
                $add(1, 'Previous abortion');
                break;
        }
    }
    $totalPregnancies = count($history) + 1;
    if ($totalPregnancies >= 3) {
        $add(1, 'Three or more past pregnancies');
    }

    // Prenatal check factors
    if (!empty($first)) {
        $sys = (int) ($first['blood_pressure_systolic'] ?? 0);
        $dia = (int) ($first['blood_pressure_diastolic'] ?? 0);
        if ($sys >= 140 || $dia >= 90) {
            $add(3, 'High blood pressure');
        }

        $edema = $first['edema'] ?? 'none';
        if ($edema === 'mild') {
            $add(1, 'Mild edema');
        } elseif ($edema === 'moderate') {
            $add(2, 'Moderate edema');
        } elseif ($edema === 'severe') {
            $add(3, 'Severe edema');
        }

        $fetalBeat = $first['fetal_heart_beat'] ?? null;
        $beatAbnormal = ($first['abnormal_fetal_heart_beat'] ?? false) ||
            ($fetalBeat !== null && ($fetalBeat < 110 || $fetalBeat > 160));
        if ($beatAbnormal) {
            $add(3, 'Abnormal fetal heartbeat');
        }

        $aog = $first['age_of_gestation'] ?? weeksBetween($lmp, $checkupDate);
        $pos = strtolower($first['fetal_position'] ?? '');
        $posAbnormal = ($first['abnormal_fetal_position'] ?? false) ||
            ($pos !== '' && $pos !== 'cephalic' && $pos !== 'vertex' && $pos !== 'unknown');
        if ($aog !== null && $aog >= 28 && $posAbnormal) {
            $add(1, 'Non-vertex fetal position (late)');
        }

        if ($aog !== null && $aog > 20) {
            $add(2, 'Late first checkup (>20 weeks)');
        }

        if (!empty($first['missed_scheduled_checkups'])) {
            $add(1, 'Missed scheduled checkups');
        }
    }

    $level = $score >= 6 ? 'high' : ($score >= 3 ? 'medium' : 'low');
    $top3 = array_slice($factors, 0, 3);

    return [
        'level' => $level,
        'score' => $score,
        'factors' => $factors,
        'note' => buildRiskNote($level, $top3),
    ];
}

try {
    expect(isset($AUTH_USER['account_type']), 'Unauthorized');
    expect($AUTH_USER['account_type'] === 'midwife', 'Only midwives can add prenatal checkups');

    $raw = file_get_contents('php://input');
    $input = json_decode($raw, true);
    expect(is_array($input), 'Invalid JSON payload');

    $pregnancyId = $input['pregnancy_id'] ?? null;
    expect(!empty($pregnancyId), 'pregnancy_id is required');

    // midwife context
    $ctx = $conn->prepare("SELECT m.midwife_id, m.assigned_bhc_id FROM midwives m WHERE m.account_id = ? LIMIT 1");
    $authAccountId = $AUTH_USER['account_id'];
    $ctx->bind_param('i', $authAccountId);
    $ctx->execute();
    $ctxRes = $ctx->get_result()->fetch_assoc();
    expect($ctxRes !== null, 'Midwife context not found');
    $midwifeId = (int) $ctxRes['midwife_id'];
    $midwifeBhcId = (int) $ctxRes['assigned_bhc_id'];

    // pregnancy context
    $pregStmt = $conn->prepare("SELECT p.pregnancy_id, p.mother_id, p.last_menstrual_period, p.status, m.assigned_bhc_id AS mother_bhc_id FROM pregnancies p JOIN mothers m ON m.mother_id = p.mother_id WHERE p.pregnancy_id = ? LIMIT 1");
    $pregStmt->bind_param('i', $pregnancyId);
    $pregStmt->execute();
    $pregRow = $pregStmt->get_result()->fetch_assoc();
    expect($pregRow !== null, 'Pregnancy not found');
    expect($pregRow['status'] === 'ongoing', 'Only ongoing pregnancies can receive prenatal checkups');
    expect((int) $pregRow['mother_bhc_id'] === $midwifeBhcId, 'Pregnancy is not assigned to your BHC');

    $motherId = (int) $pregRow['mother_id'];
    $lmp = $pregRow['last_menstrual_period'];

    $first = $input['prenatal_checkup'] ?? [];
    $checkupDateTime = fmtDateTime($first['checkup_datetime'] ?? $first['checkup_date'] ?? date('Y-m-d H:i:s'));
    $checkupDateOnly = $checkupDateTime ? date('Y-m-d', strtotime($checkupDateTime)) : null;
    $ageOfGestation = $first['age_of_gestation'] ?? weeksBetween($lmp, $checkupDateOnly);
    $nextSchedule = fmtDate($first['next_schedule'] ?? null);

    $conn->begin_transaction();

    $checkupWeight = $first['checkup_weight'] ?? null;
    $bpSys = $first['blood_pressure_systolic'] ?? null;
    $bpDia = $first['blood_pressure_diastolic'] ?? null;
    $fetalPos = $first['fetal_position'] ?? null;
    $fetalHb = $first['fetal_heart_beat'] ?? null;
    $fetalHt = $first['fetal_heart_tone'] ?? null;
    $tdDose = $first['td_vaccine_dose'] ?? null;
    $edema = $first['edema'] ?? 'none';
    $remarks = $first['remarks'] ?? null;

    // 1. Insert into prenatal_checkups table
    $prenatalStmt = $conn->prepare("INSERT INTO prenatal_checkups (pregnancy_id, midwife_id, age_of_gestation, checkup_weight, blood_pressure_systolic, blood_pressure_diastolic, fetal_position, fetal_heart_beat, fetal_heart_tone, td_vaccine_dose, edema, remarks, checkup_datetime, next_schedule) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
    $prenatalStmt->bind_param(
        'iiddiisissssss',
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
        $checkupDateTime,
        $nextSchedule
    );
    $prenatalStmt->execute();
    $prenatalId = $conn->insert_id;

    // 2. Insert into checkup_schedule table for NEXT scheduled checkup (if provided)
    if ($nextSchedule) {
        // Update any existing scheduled checkups for this date to 'completed'
        $updateStmt = $conn->prepare("UPDATE checkup_schedule SET status = 'completed' WHERE mother_id = ? AND scheduled_date = ? AND status = 'scheduled'");
        $updateStmt->bind_param('is', $motherId, $checkupDateOnly);
        $updateStmt->execute();
        
        // Insert new scheduled checkup
        $scheduleStmt = $conn->prepare("INSERT INTO checkup_schedule (mother_id, scheduled_date, notes, status) VALUES (?, ?, ?, 'scheduled')");
        $scheduleNotes = "Next prenatal checkup - AOG: " . ($ageOfGestation ? round($ageOfGestation, 1) . " weeks" : "Unknown");
        $scheduleStmt->bind_param('iss', $motherId, $nextSchedule, $scheduleNotes);
        $scheduleStmt->execute();
        $scheduleId = $conn->insert_id;
    }

    // 3. Also mark current checkup date as completed in checkup_schedule if exists
    $completeStmt = $conn->prepare("UPDATE checkup_schedule SET status = 'completed' WHERE mother_id = ? AND scheduled_date = ? AND status = 'scheduled'");
    $completeStmt->bind_param('is', $motherId, $checkupDateOnly);
    $completeStmt->execute();

    // 4. medication plans
    if (!empty($first['mother_medications'])) {
        $medPlanStmt = $conn->prepare("INSERT INTO mother_medications (mother_id, mother_medication_name, frequency, quantity, start_date, end_date, status) VALUES (?, ?, ?, ?, ?, ?, ?)");
        $medName = null;
        $medFreq = null;
        $medQty = null;
        $medStart = null;
        $medEnd = null;
        $medStatus = null;
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
        foreach ($first['mother_medications'] as $m) {
            if (empty($m['mother_medication_name'])) {
                continue;
            }
            $medName = $m['mother_medication_name'];
            $medFreq = $m['frequency'] ?? null;
            $medQty = $m['quantity'] ?? null;
            $medStart = fmtDate($m['start_date'] ?? null);
            $medEnd = fmtDate($m['end_date'] ?? null);
            $medStatus = $m['status'] ?? 'active';
            $medPlanStmt->execute();
        }
    }

    // 5. given medications
    if (!empty($first['given_medications'])) {
        $givenStmt = $conn->prepare("INSERT INTO given_medications (mother_id, given_medication_name, quantity, date_given) VALUES (?, ?, ?, ?)");
        $givenName = null;
        $givenQty = null;
        $givenDate = null;
        $givenStmt->bind_param(
            'isis',
            $motherId,
            $givenName,
            $givenQty,
            $givenDate
        );
        foreach ($first['given_medications'] as $g) {
            if (empty($g['given_medication_name']) || empty($g['quantity'])) {
                continue;
            }
            $givenName = $g['given_medication_name'];
            $givenQty = $g['quantity'];
            $givenDate = fmtDate($g['date_given'] ?? date('Y-m-d'));
            $givenStmt->execute();
        }
    }

    // 6. Recompute pregnancy risk level based on latest checkup
    $profileStmt = $conn->prepare("SELECT birthdate, height, weight FROM mothers WHERE mother_id = ? LIMIT 1");
    $profileStmt->bind_param('i', $motherId);
    $profileStmt->execute();
    $profile = $profileStmt->get_result()->fetch_assoc() ?? [];

    $condStmt = $conn->prepare("SELECT condition_name, status FROM medical_conditions WHERE mother_id = ?");
    $condStmt->bind_param('i', $motherId);
    $condStmt->execute();
    $conditions = $condStmt->get_result()->fetch_all(MYSQLI_ASSOC);

    $allStmt = $conn->prepare("SELECT status FROM allergies WHERE mother_id = ?");
    $allStmt->bind_param('i', $motherId);
    $allStmt->execute();
    $allergies = $allStmt->get_result()->fetch_all(MYSQLI_ASSOC);

    $histStmt = $conn->prepare("SELECT outcome FROM pregnancies WHERE mother_id = ? AND status = 'ended'");
    $histStmt->bind_param('i', $motherId);
    $histStmt->execute();
    $history = $histStmt->get_result()->fetch_all(MYSQLI_ASSOC);

    $risk = computeRisk(
        $profile,
        $conditions,
        $allergies,
        $history,
        $first,
        $lmp,
        $checkupDateOnly
    );
    $riskLevel = $risk['level'];

    $riskStmt = $conn->prepare("UPDATE pregnancies SET pregnancy_risk_level = ? WHERE pregnancy_id = ?");
    $riskStmt->bind_param('si', $riskLevel, $pregnancyId);
    $riskStmt->execute();

    $conn->commit();

    echo json_encode([
        'success' => true,
        'prenatal_checkup_id' => $prenatalId,
        'schedule_id' => $scheduleId ?? null,
        'pregnancy_id' => $pregnancyId,
        'mother_id' => $motherId,
        'age_of_gestation' => $ageOfGestation,
        'next_schedule' => $nextSchedule,
        'risk' => $risk,
    ]);
} catch (Throwable $e) {
    $conn->rollback();
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage(),
    ]);
}