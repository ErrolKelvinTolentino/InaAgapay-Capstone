<?php
error_reporting(0);
ini_set('display_errors', 0);
header('Content-Type: application/json');

require_once __DIR__ . '/../db.php';

$data = json_decode(file_get_contents('php://input'), true);

$child_id = isset($data['child_id']) ? intval($data['child_id']) : 0;
$vaccine_id = isset($data['vaccine_id']) ? intval($data['vaccine_id']) : 0;
$vaccination_date = $data['vaccination_date'] ?? null;
$remarks = isset($data['remarks']) ? trim($data['remarks']) : null;

if ($child_id <= 0 || $vaccine_id <= 0 || empty($vaccination_date)) {
    echo json_encode([
        'success' => false,
        'message' => 'Invalid input'
    ]);
    exit;
}

// Prevent duplicate vaccine per child
$check = $conn->prepare(
    "SELECT immunization_record_id
     FROM immunization_record
     WHERE child_id = ? AND vaccine_id = ?"
);
$check->bind_param("ii", $child_id, $vaccine_id);
$check->execute();
$res = $check->get_result();

if ($res && $res->num_rows > 0) {
    echo json_encode([
        'success' => false,
        'message' => 'Vaccine already recorded'
    ]);
    exit;
}
$check->close();

// Insert record
$stmt = $conn->prepare(
    "INSERT INTO immunization_record
     (child_id, vaccine_id, vaccination_date, remarks)
     VALUES (?, ?, ?, ?)"
);
$stmt->bind_param(
    "iiss",
    $child_id,
    $vaccine_id,
    $vaccination_date,
    $remarks
);

if ($stmt->execute()) {
    echo json_encode([
        'success' => true
    ]);
} else {
    echo json_encode([
        'success' => false,
        'message' => 'Insert failed'
    ]);
}

$stmt->close();
$conn->close();
exit;
