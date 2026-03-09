<?php
require_once __DIR__ . '/../auth/auth_check.php';
header('Content-Type: application/json');

$childId = $_GET['child_id'] ?? null;

if (!$childId) {
    echo json_encode([
        'success' => false,
        'message' => 'Missing child_id'
    ]);
    exit;
}

$stmt = $conn->prepare("
    SELECT
        child_details_id,
        child_height,
        child_weight,
        ROUND(child_weight / POW(child_height / 100, 2), 1) AS bmi,
        created_at
    FROM child_details
    WHERE child_id = ?
    ORDER BY created_at DESC
");
$stmt->bind_param("i", $childId);
$stmt->execute();

$records = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);

echo json_encode([
    'success' => true,
    'records' => $records
]);
