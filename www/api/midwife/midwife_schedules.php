<?php
header('Content-Type: application/json');
require_once '../db.php';

$sql = "
SELECT
    cs.schedule_id,
    cs.scheduled_date,
    cs.status,
    CONCAT(a.first_name, ' ', a.last_name) AS mother_name
FROM checkup_schedule cs
JOIN mothers m ON cs.mother_id = m.mother_id
JOIN accounts a ON m.account_id = a.account_id
ORDER BY cs.scheduled_date ASC
";

$result = $conn->query($sql);

$schedules = [];

while ($row = $result->fetch_assoc()) {
    $schedules[] = $row;
}

echo json_encode([
    'success' => true,
    'data' => $schedules
]);
