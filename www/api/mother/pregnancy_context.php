<?php
require_once __DIR__ . '/../auth/auth_check.php';
require_once __DIR__ . '/../db.php';

header('Content-Type: application/json');

if (($AUTH_USER['account_type'] ?? null) !== 'mother') {
    echo json_encode([
        'success' => false,
        'message' => 'Unauthorized'
    ]);
    exit;
}

$accountId = $AUTH_USER['account_id'];

// Get mother_id
$stmt = $conn->prepare("
    SELECT mother_id
    FROM mothers
    WHERE account_id = ?
    LIMIT 1
");
$stmt->bind_param("i", $accountId);
$stmt->execute();
$mother = $stmt->get_result()->fetch_assoc();

if (!$mother) {
    echo json_encode([
        'success' => false,
        'message' => 'Mother profile not found'
    ]);
    exit;
}

// Get active pregnancy
$stmt = $conn->prepare("
    SELECT
        pregnancy_id,
        last_menstrual_period,
        expected_date_of_delivery,
        status
    FROM pregnancies
    WHERE mother_id = ?
      AND status = 'ongoing'
    LIMIT 1
");
$stmt->bind_param("i", $mother['mother_id']);
$stmt->execute();
$pregnancy = $stmt->get_result()->fetch_assoc();

echo json_encode([
    'success' => true,
    'has_active_pregnancy' => $pregnancy ? true : false,
    'pregnancy' => $pregnancy
]);
