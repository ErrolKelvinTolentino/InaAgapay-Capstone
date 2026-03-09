<?php
require_once __DIR__ . '/../auth/auth_check.php';
require_once __DIR__ . '/../db.php';

header('Content-Type: application/json');

$accountId = $AUTH_USER['account_id'];

// Get mother_id
$stmt = $conn->prepare("
    SELECT mother_id FROM mothers WHERE account_id = ?
");
$stmt->bind_param("i", $accountId);
$stmt->execute();
$motherResult = $stmt->get_result();
$mother = $motherResult->fetch_assoc();

if (!$mother) {
    echo json_encode([
        'success' => false,
        'message' => 'Mother profile not found'
    ]);
    exit;
}

$motherId = $mother['mother_id'];

// Get ALL pregnancies for this mother
$stmt = $conn->prepare("
    SELECT pregnancy_id FROM pregnancies
    WHERE mother_id = ?
    ORDER BY created_at DESC
");
$stmt->bind_param("i", $motherId);
$stmt->execute();
$pregnanciesResult = $stmt->get_result();
$pregnancyIds = [];

while ($preg = $pregnanciesResult->fetch_assoc()) {
    $pregnancyIds[] = $preg['pregnancy_id'];
}

// If no pregnancies found, return empty records
if (empty($pregnancyIds)) {
    echo json_encode([
        'success' => true,
        'records' => []
    ]);
    exit;
}

// Create placeholders for IN clause
$placeholders = str_repeat('?,', count($pregnancyIds) - 1) . '?';

// Get ALL lab test records from ALL pregnancies for this mother
$stmt = $conn->prepare("
    SELECT
        l.lab_test_id,
        l.lab_test_date,
        l.lab_test_type,
        l.lab_test_location,
        l.lab_test_image,
        l.remarks,
        l.health_worker_name,
        l.health_worker_institution,
        l.health_worker_profession,
        l.created_at,
        p.pregnancy_id,
        p.status as pregnancy_status,
        p.expected_date_of_delivery
    FROM lab_tests l
    INNER JOIN pregnancies p ON l.pregnancy_id = p.pregnancy_id
    WHERE l.pregnancy_id IN ($placeholders)
    ORDER BY l.lab_test_date DESC
");

// Bind pregnancy IDs
$types = str_repeat('i', count($pregnancyIds));
$stmt->bind_param($types, ...$pregnancyIds);
$stmt->execute();
$result = $stmt->get_result();

$records = [];
while ($row = $result->fetch_assoc()) {
    $records[] = $row;
}

echo json_encode([
    'success' => true,
    'records' => $records,
    'total' => count($records)
]);