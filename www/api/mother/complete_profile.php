<?php
require_once __DIR__ . '/../auth/auth_check.php';
require_once __DIR__ . '/../db.php';

header('Content-Type: application/json');

$accountId = $AUTH_USER['account_id'];

$data = json_decode(file_get_contents("php://input"), true);

// ============================
// VALIDATION
// ============================
$required = ['first_name', 'last_name', 'birth_date', 'contact_number'];

foreach ($required as $field) {
    if (empty($data[$field])) {
        echo json_encode([
            'success' => false,
            'message' => "Missing required field: $field"
        ]);
        exit;
    }
}

// ============================
// UPDATE ACCOUNTS
// ============================
$stmt = $conn->prepare("
    UPDATE accounts
    SET first_name = ?,
        middle_name = ?,
        last_name = ?,
        extension_name = ?,
        phone_number = ?
    WHERE account_id = ?
");

$stmt->bind_param(
    "sssssi",
    $data['first_name'],
    $data['middle_name'],
    $data['last_name'],
    $data['extension_name'],
    $data['contact_number'],
    $accountId
);

$stmt->execute();

// ============================
// CREATE / UPDATE MOTHER PROFILE
// ============================
$stmt = $conn->prepare("
    SELECT mother_id
    FROM mothers
    WHERE account_id = ?
    LIMIT 1
");
$stmt->bind_param("i", $accountId);
$stmt->execute();
$res = $stmt->get_result()->fetch_assoc();

$birthdate = date('Y-m-d', strtotime($data['birth_date']));

if ($res) {
    // UPDATE
    $stmt = $conn->prepare("
        UPDATE mothers
        SET birthdate = ?,
            house_number = ?,
            street = ?,
            barangay = ?,
            city_municipality = ?,
            province = ?
        WHERE account_id = ?
    ");

    $stmt->bind_param(
        "ssssssi",
        $birthdate,
        $data['house_no'],
        $data['street'],
        $data['barangay'],
        $data['city'],
        $data['province'],
        $accountId
    );
} else {
    // INSERT
    $stmt = $conn->prepare("
        INSERT INTO mothers
        (account_id, birthdate, house_number, street, barangay, city_municipality, province)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ");

    $stmt->bind_param(
        "issssss",
        $accountId,
        $birthdate,
        $data['house_no'],
        $data['street'],
        $data['barangay'],
        $data['city'],
        $data['province']
    );
}

$stmt->execute();

// ============================
// DONE
// ============================
echo json_encode([
    'success' => true,
    'message' => 'Profile completed successfully'
]);
