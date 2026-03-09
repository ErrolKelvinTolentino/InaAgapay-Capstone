<?php
require_once __DIR__ . '/../auth/auth_check.php';
require_once __DIR__ . '/../db.php';

header('Content-Type: application/json');

if ($AUTH_USER['account_type'] !== 'mother') {
    echo json_encode(['success' => false]);
    exit;
}

$accountId = $AUTH_USER['account_id'];

/* Get mother */
$stmt = $conn->prepare("
    SELECT mother_id FROM mothers WHERE account_id = ?
");
$stmt->bind_param("i", $accountId);
$stmt->execute();
$mother = $stmt->get_result()->fetch_assoc();

if (!$mother) {
    echo json_encode(['success' => false]);
    exit;
}

/* Latest pregnancy */
$stmt = $conn->prepare("
    SELECT pregnancy_id
    FROM pregnancies
    WHERE mother_id = ? AND status = 'ongoing'
    ORDER BY created_at DESC
    LIMIT 1
");
$stmt->bind_param("i", $mother['mother_id']);
$stmt->execute();
$pregnancy = $stmt->get_result()->fetch_assoc();

if (!$pregnancy) {
    echo json_encode(['success' => true, 'data' => null]);
    exit;
}

/* Latest checkup */
$stmt = $conn->prepare("
    SELECT
        checkup_date,
        next_schedule,
        checkup_weight,
        blood_pressure_systolic,
        blood_pressure_diastolic
    FROM prenatal_checkups
    WHERE pregnancy_id = ?
    ORDER BY checkup_date DESC
    LIMIT 1
");
$stmt->bind_param("i", $pregnancy['pregnancy_id']);
$stmt->execute();
$latest = $stmt->get_result()->fetch_assoc();

/* History */
$stmt = $conn->prepare("
    SELECT checkup_date
    FROM prenatal_checkups
    WHERE pregnancy_id = ?
    ORDER BY checkup_date DESC
");
$stmt->bind_param("i", $pregnancy['pregnancy_id']);
$stmt->execute();
$history = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);

echo json_encode([
    'success' => true,
    'latest' => $latest,
    'history' => $history
]);
