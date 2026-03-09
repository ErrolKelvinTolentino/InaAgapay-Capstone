<?php
require_once __DIR__ . '/../db.php';

require_once __DIR__ . '/../../mailer.php';

$data = json_decode(file_get_contents("php://input"), true);
$email = $data['email'];

$code = rand(100000, 999999);
$expires = date("Y-m-d H:i:s", strtotime("+5 minutes"));

$stmt = $conn->prepare("
    UPDATE accounts
    SET reset_code=?, reset_expires=?
    WHERE email_address=?
");
$stmt->bind_param("sss", $code, $expires, $email);

if (!$stmt->execute() || $stmt->affected_rows === 0) {
    echo json_encode(['success' => false]);
    exit;
}

sendMail($email, "Password Reset Code", "Your code: $code");
echo json_encode(['success' => true]);
