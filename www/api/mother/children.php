<?php
require_once __DIR__ . '/../auth/auth_check.php';
require_once __DIR__ . '/../db.php';

header('Content-Type: application/json');

if (($AUTH_USER['account_type'] ?? null) !== 'mother') {
    echo json_encode(['success' => false]);
    exit;
}

$accountId = $AUTH_USER['account_id'];

$stmt = $conn->prepare("
    SELECT mother_id
    FROM mothers
    WHERE account_id = ?
    LIMIT 1
");
$stmt->bind_param("i", $accountId);
$stmt->execute();
$mother = $stmt->get_result()->fetch_assoc();

$stmt = $conn->prepare("
    SELECT
        c.child_id,
        c.first_name,
        c.last_name,
        c.sex,
        bd.birthdate
    FROM children c
    LEFT JOIN birth_details bd ON bd.child_id = c.child_id
    WHERE c.mother_id = ?
");
$stmt->bind_param("i", $mother['mother_id']);
$stmt->execute();

echo json_encode([
    'success' => true,
    'children' => $stmt->get_result()->fetch_all(MYSQLI_ASSOC)
]);
