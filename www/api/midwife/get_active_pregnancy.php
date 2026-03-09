<?php
require_once __DIR__ . '/../auth/auth_check.php';
header('Content-Type: application/json');

$motherId = $_GET['mother_id'] ?? null;

if (!$motherId) {
    echo json_encode([
        'success' => false,
        'message' => 'Mother ID required'
    ]);
    exit;
}

$stmt = $conn->prepare("
    SELECT pregnancy_id
    FROM pregnancies
    WHERE mother_id = ?
      AND status = 'ongoing'
    LIMIT 1
");

$stmt->bind_param("i", $motherId);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows === 0) {
    echo json_encode([
        'success' => false,
        'message' => 'No active pregnancy'
    ]);
    exit;
}

echo json_encode([
    'success' => true,
    'pregnancy_id' => $result->fetch_assoc()['pregnancy_id']
]);
