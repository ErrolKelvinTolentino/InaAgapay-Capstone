<?php
require_once __DIR__ . '/../db.php';

$data = json_decode(file_get_contents("php://input"), true);

$email = $data['email'];
$code = $data['code'];

$stmt = $conn->prepare("
    SELECT reset_code, reset_expires
    FROM accounts WHERE email_address=?
");
$stmt->bind_param("s", $email);
$stmt->execute();
$res = $stmt->get_result()->fetch_assoc();

if (
    !$res || $res['reset_code'] !== $code ||
    strtotime($res['reset_expires']) < time()
) {
    echo json_encode(['success' => false]);
    exit;
}

echo json_encode(['success' => true]);
