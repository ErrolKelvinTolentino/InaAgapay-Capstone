<?php
require_once __DIR__ . '/../auth/auth_check.php';
require_once __DIR__ . '/../db.php';

header('Content-Type: application/json');

if ($AUTH_USER['account_type'] !== 'mother') {
    http_response_code(403);
    echo json_encode(['success' => false, 'message' => 'Forbidden']);
    exit;
}

/**
 * GET mother_id
 */
$stmt = $conn->prepare("
    SELECT mother_id
    FROM mothers
    WHERE account_id = ?
    LIMIT 1
");
$stmt->bind_param("i", $AUTH_USER['account_id']);
$stmt->execute();
$mother = $stmt->get_result()->fetch_assoc();

if (!$mother) {
    echo json_encode(['success' => false, 'message' => 'Mother profile not found']);
    exit;
}

$motherId = $mother['mother_id'];

/**
 * GET children
 */
$stmt = $conn->prepare("
    SELECT 
        c.child_id,
        c.first_name,
        c.middle_name,
        c.last_name,
        c.extension_name,
        c.sex,
        bd.birthdate
    FROM children c
    LEFT JOIN birth_details bd ON bd.child_id = c.child_id
    WHERE c.mother_id = ?
    ORDER BY c.added_at DESC
");
$stmt->bind_param("i", $motherId);
$stmt->execute();

$result = $stmt->get_result();
$children = [];

while ($row = $result->fetch_assoc()) {
    $children[] = $row;
}

echo json_encode([
    'success' => true,
    'count' => count($children),
    'children' => $children
]);
