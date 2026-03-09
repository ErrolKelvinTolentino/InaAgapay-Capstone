<?php
require_once __DIR__ . '/../auth/auth_check.php';
header('Content-Type: application/json');

$motherId = $_POST['mother_id'] ?? null;
$date = $_POST['scheduled_date'] ?? null;
$notes = $_POST['notes'] ?? null;

if (!$motherId || !$date) {
    echo json_encode([
        'success' => false,
        'message' => 'Missing required fields'
    ]);
    exit;
}

$stmt = $conn->prepare("
    INSERT INTO checkup_schedule (mother_id, scheduled_date, notes)
    VALUES (?, ?, ?)
");

$stmt->bind_param("iss", $motherId, $date, $notes);

if ($stmt->execute()) {
    echo json_encode([
        'success' => true,
        'schedule_id' => $stmt->insert_id
    ]);
} else {
    echo json_encode([
        'success' => false,
        'message' => 'Insert failed'
    ]);
}
