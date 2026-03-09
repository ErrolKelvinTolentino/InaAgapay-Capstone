<?php
require_once __DIR__ . '/../db.php';

$data = json_decode(file_get_contents("php://input"), true);

$email = $data['email'];
$hash = password_hash($data['password'], PASSWORD_DEFAULT);

$stmt = $conn->prepare("
    UPDATE accounts
    SET password_hash=?, reset_code=NULL, reset_expires=NULL
    WHERE email_address=?
");
$stmt->bind_param("ss", $hash, $email);
$stmt->execute();

echo json_encode(['success' => true]);
