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
        ir.immunization_record_id,
        v.vaccine_name,
        v.dose_number,
        ir.vaccination_date,
        ir.remarks
    FROM immunization_record ir
    JOIN vaccines v ON v.vaccine_id = ir.vaccine_id
    WHERE ir.child_id = ?
    ORDER BY ir.vaccination_date DESC
");
$stmt->bind_param("i", $childId);
$stmt->execute();

$records = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);

echo json_encode([
    'success' => true,
    'records' => $records
]);
