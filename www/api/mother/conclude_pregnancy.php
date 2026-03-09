<?php
require_once __DIR__ . '/../auth/auth_check.php';
require_once __DIR__ . '/../db.php';

header('Content-Type: application/json');

if (($AUTH_USER['account_type'] ?? null) !== 'mother') {
    echo json_encode(['success' => false, 'message' => 'Unauthorized']);
    exit;
}

$data = json_decode(file_get_contents("php://input"), true);
$outcome = $data['outcome'] ?? null; // live_birth, miscarriage, etc.
$outcomeDate = $data['outcome_date'] ?? date('Y-m-d');

if (!$outcome) {
    echo json_encode(['success' => false, 'message' => 'Outcome required']);
    exit;
}

// Get mother
$stmt = $conn->prepare("
    SELECT mother_id
    FROM mothers
    WHERE account_id = ?
    LIMIT 1
");
$stmt->bind_param("i", $AUTH_USER['account_id']);
$stmt->execute();
$mother = $stmt->get_result()->fetch_assoc();

if (!$mother) {
    echo json_encode(['success' => false, 'message' => 'Mother not found']);
    exit;
}

// Get active pregnancy
$stmt = $conn->prepare("
    SELECT pregnancy_id, last_menstrual_period
    FROM pregnancies
    WHERE mother_id = ?
      AND status = 'ongoing'
    LIMIT 1
");
$stmt->bind_param("i", $mother['mother_id']);
$stmt->execute();
$pregnancy = $stmt->get_result()->fetch_assoc();

if (!$pregnancy) {
    echo json_encode(['success' => false, 'message' => 'No active pregnancy']);
    exit;
}

// Compute gestational age
$lmp = new DateTime($pregnancy['last_menstrual_period']);
$outcomeDt = new DateTime($outcomeDate);
$weeks = round($lmp->diff($outcomeDt)->days / 7, 1);

// Close pregnancy
$stmt = $conn->prepare("
    UPDATE pregnancies
    SET status = 'ended',
        outcome = ?,
        outcome_date = ?,
        gestational_age_at_end = ?,
        ended_at = NOW()
    WHERE pregnancy_id = ?
");
$stmt->bind_param("ssdi", $outcome, $outcomeDate, $weeks, $pregnancy['pregnancy_id']);
$stmt->execute();

echo json_encode([
    'success' => true,
    'message' => 'Pregnancy concluded'
]);
