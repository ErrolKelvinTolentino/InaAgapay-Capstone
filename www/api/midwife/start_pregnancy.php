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
    array $latestCheckup,
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

    // Latest checkup factors (if any)
    if (!empty($latestCheckup)) {
        $sys = (int) ($latestCheckup['blood_pressure_systolic'] ?? 0);
        $dia = (int) ($latestCheckup['blood_pressure_diastolic'] ?? 0);
        if ($sys >= 140 || $dia >= 90) {
            $add(3, 'High blood pressure');
        }

        $edema = $latestCheckup['edema'] ?? 'none';
        if ($edema === 'mild') {
            $add(1, 'Mild edema');
        } elseif ($edema === 'moderate') {
            $add(2, 'Moderate edema');
        } elseif ($edema === 'severe') {
            $add(3, 'Severe edema');
        }

        $fetalBeat = $latestCheckup['fetal_heart_beat'] ?? null;
        $beatAbnormal = ($latestCheckup['abnormal_fetal_heart_beat'] ?? false) ||
            ($fetalBeat !== null && ($fetalBeat < 110 || $fetalBeat > 160));
        if ($beatAbnormal) {
            $add(3, 'Abnormal fetal heartbeat');
        }

        $aog = $latestCheckup['age_of_gestation'] ?? weeksBetween($lmp, $checkupDate);
        $pos = strtolower($latestCheckup['fetal_position'] ?? '');
        $posAbnormal = ($latestCheckup['abnormal_fetal_position'] ?? false) ||
            ($pos !== '' && $pos !== 'cephalic' && $pos !== 'vertex' && $pos !== 'unknown');
        if ($aog !== null && $aog >= 28 && $posAbnormal) {
            $add(1, 'Non-vertex fetal position (late)');
        }

        if ($aog !== null && $aog > 20) {
            $add(2, 'Late first checkup (>20 weeks)');
        }

        if (!empty($latestCheckup['missed_scheduled_checkups'])) {
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
    expect($AUTH_USER['account_type'] === 'midwife', 'Only midwives can start pregnancies');

    $raw = file_get_contents('php://input');
    $input = json_decode($raw, true);
    expect(is_array($input), 'Invalid JSON payload');

    $motherId = $input['mother_id'] ?? null;
    $lmp = fmtDate($input['last_menstrual_period'] ?? null);
    $edd = fmtDate($input['expected_date_of_delivery'] ?? null);
    expect(!empty($motherId), 'mother_id is required');

    // midwife context
    $ctx = $conn->prepare("SELECT m.midwife_id, m.assigned_bhc_id FROM midwives m WHERE m.account_id = ? LIMIT 1");
    $authAccountId = $AUTH_USER['account_id'];
    $ctx->bind_param('i', $authAccountId);
    $ctx->execute();
    $ctxRes = $ctx->get_result()->fetch_assoc();
    expect($ctxRes !== null, 'Midwife context not found');
    $midwifeBhcId = (int) $ctxRes['assigned_bhc_id'];

    // mother context
    $momStmt = $conn->prepare("SELECT mother_id, birthdate, height, weight, assigned_bhc_id FROM mothers WHERE mother_id = ? LIMIT 1");
    $momStmt->bind_param('i', $motherId);
    $momStmt->execute();
    $mother = $momStmt->get_result()->fetch_assoc();
    expect($mother !== null, 'Mother not found');
    expect((int) $mother['assigned_bhc_id'] === $midwifeBhcId, 'Mother is not assigned to your BHC');

    // ensure no ongoing pregnancy
    $ongoingStmt = $conn->prepare("SELECT COUNT(*) AS c FROM pregnancies WHERE mother_id = ? AND status = 'ongoing'");
    $ongoingStmt->bind_param('i', $motherId);
    $ongoingStmt->execute();
    $ongoing = $ongoingStmt->get_result()->fetch_assoc();
    expect(($ongoing['c'] ?? 0) == 0, 'Mother already has an ongoing pregnancy');

    // supporting data
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

    $risk = computeRisk($mother, $conditions, $allergies, $history, [], $lmp, null);

    $conn->begin_transaction();

    $insert = $conn->prepare("INSERT INTO pregnancies (mother_id, pregnancy_risk_level, last_menstrual_period, expected_date_of_delivery, status) VALUES (?, ?, ?, ?, 'ongoing')");
    $insert->bind_param('isss', $motherId, $risk['level'], $lmp, $edd);
    $insert->execute();
    $pregnancyId = $conn->insert_id;

    $conn->commit();

    echo json_encode([
        'success' => true,
        'pregnancy_id' => $pregnancyId,
        'pregnancy_risk_level' => $risk['level'],
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
