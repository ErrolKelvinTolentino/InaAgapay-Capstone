<?php
require_once __DIR__ . '/../auth/auth_check.php';
header('Content-Type: application/json');

// ---------- Helpers ----------
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

    // Prenatal check factors (latest)
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

$motherId = $_GET['mother_id'] ?? null;

if (!$motherId) {
    echo json_encode([
        'success' => false,
        'message' => 'Mother ID is required'
    ]);
    exit;
}

$stmt = $conn->prepare("
    SELECT
        mo.mother_id,
        a.first_name,
        a.middle_name,
        a.last_name,
        a.extension_name,
        a.email_address,
        a.phone_number,
        a.status,

        mo.house_number,
        mo.street,
        mo.barangay,
        mo.city_municipality,
        mo.province,
        mo.height,
        mo.weight,
        mo.blood_type,
        mo.birthdate,

        p.pregnancy_id,
        p.pregnancy_risk_level,
        p.status AS pregnancy_status,
        p.expected_date_of_delivery,
        p.last_menstrual_period,

        (SELECT COUNT(*) FROM children c WHERE c.mother_id = mo.mother_id) AS children_count

    FROM mothers mo
    JOIN accounts a ON a.account_id = mo.account_id
    LEFT JOIN pregnancies p 
        ON p.mother_id = mo.mother_id 
        AND p.status = 'ongoing'

    WHERE mo.mother_id = ?
    LIMIT 1
");

$stmt->bind_param("i", $motherId);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows === 0) {
    echo json_encode([
        'success' => false,
        'message' => 'Mother not found'
    ]);
    exit;
}

$mother = $result->fetch_assoc();

// Medical conditions
$medStmt = $conn->prepare("SELECT condition_name, diagnosis_date, status, remarks, created_at FROM medical_conditions WHERE mother_id = ? ORDER BY created_at DESC");
$medStmt->bind_param('i', $motherId);
$medStmt->execute();
$medRes = $medStmt->get_result();
$medicalConditions = $medRes->fetch_all(MYSQLI_ASSOC);

// Allergies
$allStmt = $conn->prepare("SELECT allergen, diagnosis_date, status, treatment, remarks, created_at FROM allergies WHERE mother_id = ? ORDER BY created_at DESC");
$allStmt->bind_param('i', $motherId);
$allStmt->execute();
$allRes = $allStmt->get_result();
$allergies = $allRes->fetch_all(MYSQLI_ASSOC);

// Emergency contacts
$emcStmt = $conn->prepare("SELECT * FROM emergency_contacts WHERE mother_id = ? AND status = 'active' ORDER BY created_at DESC");
$emcStmt->bind_param('i', $motherId);
$emcStmt->execute();
$emergencyContacts = $emcStmt->get_result()->fetch_all(MYSQLI_ASSOC);

// Medications
$planStmt = $conn->prepare("SELECT * FROM mother_medications WHERE mother_id = ? ORDER BY created_at DESC");
$planStmt->bind_param('i', $motherId);
$planStmt->execute();
$motherMedications = $planStmt->get_result()->fetch_all(MYSQLI_ASSOC);

$givenStmt = $conn->prepare("SELECT * FROM given_medications WHERE mother_id = ? ORDER BY date_given DESC, given_medication_id DESC");
$givenStmt->bind_param('i', $motherId);
$givenStmt->execute();
$givenMedications = $givenStmt->get_result()->fetch_all(MYSQLI_ASSOC);

// Children
$childStmt = $conn->prepare("SELECT child_id, first_name, middle_name, last_name, extension_name, sex, added_at FROM children WHERE mother_id = ? ORDER BY added_at DESC");
$childStmt->bind_param('i', $motherId);
$childStmt->execute();
$children = $childStmt->get_result()->fetch_all(MYSQLI_ASSOC);

// Pregnancies (current + past)
$pregStmt = $conn->prepare("SELECT * FROM pregnancies WHERE mother_id = ? ORDER BY created_at DESC");
$pregStmt->bind_param('i', $motherId);
$pregStmt->execute();
$pregRes = $pregStmt->get_result();

$currentPregnancy = null;
$pastPregnancies = [];

while ($p = $pregRes->fetch_assoc()) {
    $pid = (int) $p['pregnancy_id'];

    // Prenatal checkups
    $chkStmt = $conn->prepare("SELECT * FROM prenatal_checkups WHERE pregnancy_id = ? ORDER BY checkup_datetime DESC, prenatal_checkup_id DESC");
    $chkStmt->bind_param('i', $pid);
    $chkStmt->execute();
    $checkups = $chkStmt->get_result()->fetch_all(MYSQLI_ASSOC);

    // Attach supplement totals per checkup (from given_medications)
    foreach ($checkups as &$chk) {
        $chkDateRaw = $chk['checkup_datetime'] ?? $chk['checkup_date'] ?? null;
        $chkDate = $chkDateRaw ? date('Y-m-d', strtotime($chkDateRaw)) : null;
        $ferrousGiven = 0;
        $calciumGiven = 0;

        if ($chkDate !== null) {
            foreach ($givenMedications as $gm) {
                $gmDateRaw = $gm['date_given'] ?? null;
                $gmDate = $gmDateRaw ? date('Y-m-d', strtotime($gmDateRaw)) : null;
                if ($gmDate !== $chkDate) {
                    continue;
                }

                $name = strtolower($gm['given_medication_name'] ?? '');
                $qty = (int) ($gm['quantity'] ?? 0);

                if (strpos($name, 'ferrous') !== false) {
                    $ferrousGiven += $qty;
                }
                if (strpos($name, 'calcium') !== false) {
                    $calciumGiven += $qty;
                }
            }
        }

        $chk['ferrous_given'] = $ferrousGiven;
        $chk['calcium_given'] = $calciumGiven;
    }
    unset($chk);

    // Ultrasounds
    $usStmt = $conn->prepare("SELECT * FROM ultrasounds WHERE pregnancy_id = ? ORDER BY ultrasound_date DESC");
    $usStmt->bind_param('i', $pid);
    $usStmt->execute();
    $ultrasounds = $usStmt->get_result()->fetch_all(MYSQLI_ASSOC);

    // Lab tests
    $labStmt = $conn->prepare("SELECT * FROM lab_tests WHERE pregnancy_id = ? ORDER BY lab_test_date DESC");
    $labStmt->bind_param('i', $pid);
    $labStmt->execute();
    $labTests = $labStmt->get_result()->fetch_all(MYSQLI_ASSOC);

    // Delivery (if any)
    $deliveryStmt = $conn->prepare("SELECT * FROM deliveries WHERE pregnancy_id = ? LIMIT 1");
    $deliveryStmt->bind_param('i', $pid);
    $deliveryStmt->execute();
    $delivery = $deliveryStmt->get_result()->fetch_assoc();

    $p['checkups'] = $checkups;
    $p['ultrasounds'] = $ultrasounds;
    $p['lab_tests'] = $labTests;
    $p['delivery'] = $delivery;

    // attach risk snapshot (uses latest checkup if available)
    $latestCheckup = $checkups[0] ?? [];
    $latestCheckDate = null;
    if (!empty($latestCheckup['checkup_datetime'])) {
        $latestCheckDate = date('Y-m-d', strtotime($latestCheckup['checkup_datetime']));
    }
    $risk = computeRisk(
        [
            'birthdate' => $mother['birthdate'] ?? null,
            'height' => $mother['height'] ?? null,
            'weight' => $mother['weight'] ?? null,
        ],
        $medicalConditions,
        $allergies,
        $pastPregnancies,
        $latestCheckup,
        $p['last_menstrual_period'] ?? null,
        $latestCheckDate
    );
    $p['risk'] = $risk;

    if ($p['status'] === 'ongoing' && $currentPregnancy === null) {
        $currentPregnancy = $p;
    } else {
        $pastPregnancies[] = $p;
    }
}

$mother['medical_conditions'] = $medicalConditions;
$mother['allergies'] = $allergies;
$mother['emergency_contacts'] = $emergencyContacts;
$mother['mother_medications'] = $motherMedications;
$mother['given_medications'] = $givenMedications;
$mother['children'] = $children;
$mother['current_pregnancy'] = $currentPregnancy;
$mother['past_pregnancies'] = $pastPregnancies;

// Surface latest risk on mother root for quick access
if ($currentPregnancy && isset($currentPregnancy['risk'])) {
    $mother['pregnancy_risk_level'] = $currentPregnancy['risk']['level'];
    $mother['pregnancy_risk'] = $currentPregnancy['risk'];
}

echo json_encode([
    'success' => true,
    'mother' => $mother
]);
