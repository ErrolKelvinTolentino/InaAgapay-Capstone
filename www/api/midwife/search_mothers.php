<?php
require_once __DIR__ . '/../auth/auth_check.php';
header('Content-Type: application/json');

$q = $_GET['q'] ?? '';

$sql = "
    SELECT
        m.mother_id,
        CONCAT(
            a.first_name, ' ',
            IFNULL(CONCAT(LEFT(a.middle_name,1), '. '), ''),
            a.last_name,
            IF(a.extension_name IS NOT NULL AND a.extension_name != '', CONCAT(' ', a.extension_name), '')
        ) AS full_name
    FROM mothers m
    JOIN accounts a ON a.account_id = m.account_id
    WHERE m.status = 'active'
      AND (
        a.first_name LIKE ?
        OR a.last_name LIKE ?
        OR a.middle_name LIKE ?
      )
    ORDER BY a.last_name
";

$like = "%$q%";
$stmt = $conn->prepare($sql);
$stmt->bind_param("sss", $like, $like, $like);
$stmt->execute();

$result = $stmt->get_result();
$mothers = [];

while ($row = $result->fetch_assoc()) {
    $mothers[] = [
        'mother_id' => (int)$row['mother_id'],
        'name' => $row['full_name'],
    ];
}

echo json_encode([
    'success' => true,
    'data' => $mothers
]);
