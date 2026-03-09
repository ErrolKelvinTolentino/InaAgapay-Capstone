<?php
require_once __DIR__ . '/../db.php';
header('Content-Type: application/json');

$q = $conn->query("
  SELECT vaccine_id, vaccine_name, dose_number, recommended_age_months
  FROM vaccines
  WHERE target_recipients = 'child'
  ORDER BY vaccine_name, dose_number
");

$data = [];
while ($row = $q->fetch_assoc()) {
  $data[] = $row;
}

echo json_encode([
  'success' => true,
  'data' => $data
]);
