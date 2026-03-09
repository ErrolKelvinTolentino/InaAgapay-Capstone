<?php
require_once __DIR__ . '/../db.php';
require_once __DIR__ . '/../auth/auth_check.php';

header('Content-Type: application/json');

if ($AUTH_USER['account_type'] !== 'mother') {
    echo json_encode(['success' => false]);
    exit;
}

$childId = (int)($_GET['child_id'] ?? 0);
$accountId = $AUTH_USER['account_id'];

/* VERIFY CHILD */
$verify = $conn->prepare("
    SELECT c.child_id, bd.birthdate
    FROM children c
    JOIN mothers m ON c.mother_id = m.mother_id
    LEFT JOIN birth_details bd ON c.child_id = bd.child_id
    WHERE c.child_id = ? AND m.account_id = ?
");
$verify->bind_param("ii", $childId, $accountId);
$verify->execute();
$child = $verify->get_result()->fetch_assoc();

if (!$child || !$child['birthdate']) {
    echo json_encode(['success' => true, 'vaccines' => []]);
    exit;
}

/* AGE IN WEEKS */
$birth = new DateTime($child['birthdate']);
$now = new DateTime();
$childAgeWeeks = (int) floor($birth->diff($now)->days / 7);

/* FETCH TAKEN VACCINES */
$takenStmt = $conn->prepare("
    SELECT vaccine_id
    FROM immunization_record
    WHERE child_id = ?
");
$takenStmt->bind_param("i", $childId);
$takenStmt->execute();
$takenIds = array_column(
    $takenStmt->get_result()->fetch_all(MYSQLI_ASSOC),
    'vaccine_id'
);

/* FETCH ALL CHILD VACCINES */
$vaccinesStmt = $conn->query("
    SELECT vaccine_id, vaccine_name, dose_number, recommended_age_months
    FROM vaccines
    WHERE target_recipients = 'child'
    ORDER BY recommended_age_months, dose_number
");

$vaccines = [];

while ($v = $vaccinesStmt->fetch_assoc()) {

    $requiredWeeks = (int) round($v['recommended_age_months'] * 4.345);

    if (in_array($v['vaccine_id'], $takenIds)) {
        $status = 'done';
    } elseif ($childAgeWeeks >= $requiredWeeks) {
        $status = 'pending';
    } else {
        $status = 'locked';
    }

    $vaccines[] = [
        'vaccine_id' => (int)$v['vaccine_id'],
        'name' => $v['vaccine_name'],
        'dose' => (int)$v['dose_number'],
        'recommended_months' => (float)$v['recommended_age_months'],
        'status' => $status
    ];
}

echo json_encode([
    'success' => true,
    'child_age_weeks' => $childAgeWeeks,
    'vaccines' => $vaccines
]);
