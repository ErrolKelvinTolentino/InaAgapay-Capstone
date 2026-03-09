<?php
require_once __DIR__ . '/../auth/auth_check.php';
require_once __DIR__ . '/../db.php';

header('Content-Type: application/json');

if (($AUTH_USER['account_type'] ?? null) !== 'mother') {
    echo json_encode(['success' => false]);
    exit;
}

$accountId = $AUTH_USER['account_id'];

$stmt = $conn->prepare("
    SELECT m.mother_id
    FROM mothers m
    WHERE m.account_id = ?
    LIMIT 1
");
$stmt->bind_param("i", $accountId);
$stmt->execute();
$mother = $stmt->get_result()->fetch_assoc();

if (!$mother) {
    echo json_encode(['success' => false]);
    exit;
}

$stmt = $conn->prepare("
    SELECT scheduled_date
    FROM checkup_schedule
    WHERE mother_id = ?
      AND status = 'scheduled'
    ORDER BY scheduled_date ASC
    LIMIT 1
");
$stmt->bind_param("i", $mother['mother_id']);
$stmt->execute();
$checkup = $stmt->get_result()->fetch_assoc();

echo json_encode([
    'success' => true,
    'next_checkup' => $checkup
        ? date('F d, Y', strtotime($checkup['scheduled_date']))
        : null
]);
