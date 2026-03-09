<?php
ini_set('display_errors', 0);
error_reporting(0);
header('Content-Type: application/json');

require_once __DIR__ . '/../db.php';

$sql = "
  SELECT 
    vaccine_id,
    vaccine_name,
    dose_number,
    recommended_age_months,
    target_recipients,
    notes
  FROM vaccines
  WHERE target_recipients = 'child'
  ORDER BY vaccine_name, dose_number
";

$result = $conn->query($sql);

$vaccines = [];

if ($result) {
  while ($row = $result->fetch_assoc()) {
    $vaccines[] = $row;
  }
}

echo json_encode($vaccines);
exit;
