<?php
header('Content-Type: application/json');
require_once '../db.php';

$date = $_GET['date'] ?? date('Y-m-d');

$sql = "
SELECT
  cs.schedule_id,
  cs.scheduled_date,
  cs.status,
  CONCAT(a.first_name, ' ', a.last_name) AS mother_name
FROM checkup_schedule cs
JOIN mothers m ON cs.mother_id = m.mother_id
JOIN accounts a ON m.account_id = a.account_id
WHERE cs.scheduled_date = ?
ORDER BY a.last_name ASC
";

$stmt = $conn->prepare($sql);
$stmt->bind_param('s', $date);
$stmt->execute();

$result = $stmt->get_result();
$data = [];

while ($row = $result->fetch_assoc()) {
  $data[] = $row;
}

echo json_encode([
  'success' => true,
  'date' => $date,
  'data' => $data
]);
