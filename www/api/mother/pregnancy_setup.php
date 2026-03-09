<?php
require_once __DIR__ . '/../auth/auth_check.php';
require_once __DIR__ . '/../db.php';

header('Content-Type: application/json');

if (($AUTH_USER['account_type'] ?? null) !== 'mother') {
    echo json_encode([
        'success' => false,
        'message' => 'Unauthorized'
    ]);
    exit;
}

$data = json_decode(file_get_contents("php://input"), true);
$accountId = $AUTH_USER['account_id'];

// Get mother_id
$stmt = $conn->prepare("
    SELECT mother_id
    FROM mothers
    WHERE account_id = ?
    LIMIT 1
");
$stmt->bind_param("i", $accountId);
$stmt->execute();
$mother = $stmt->get_result()->fetch_assoc();

if (!$mother) {
    echo json_encode([
        'success' => false,
        'message' => 'Mother profile not found'
    ]);
    exit;
}

$motherId = $mother['mother_id'];

// Prevent multiple active pregnancies
$check = $conn->prepare("
    SELECT pregnancy_id
    FROM pregnancies
    WHERE mother_id = ?
      AND status = 'ongoing'
    LIMIT 1
");
$check->bind_param("i", $motherId);
$check->execute();

if ($check->get_result()->num_rows > 0) {
    echo json_encode([
        'success' => false,
        'message' => 'Active pregnancy already exists'
    ]);
    exit;
}

// Read inputs
$lmp = $data['lmp'] ?? null;
$edd = $data['edd'] ?? null;

// Insert pregnancy
$stmt = $conn->prepare("
    INSERT INTO pregnancies (
        mother_id,
        last_menstrual_period,
        expected_date_of_delivery,
        status
    ) VALUES (?, ?, ?, 'ongoing')
");

$stmt->bind_param(
    "iss",
    $motherId,
    $lmp,
    $edd
);

$stmt->execute();

echo json_encode([
    'success' => true,
    'message' => 'Pregnancy initialized'
]);
