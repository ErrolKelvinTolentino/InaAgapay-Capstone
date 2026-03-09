<?php
require_once __DIR__ . '/../db.php';

$res = $conn->query("
    SELECT vaccine_id, vaccine_name, dose_number
    FROM vaccines
    ORDER BY vaccine_name, dose_number
");

$data = [];
while ($row = $res->fetch_assoc()) {
    $data[] = $row;
}

echo json_encode([
    'success' => true,
    'data' => $data
]);
