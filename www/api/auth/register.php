<?php
header('Content-Type: application/json');

require_once __DIR__ . '/../db.php';
require_once __DIR__ . '/../../mailer.php';

$data = json_decode(file_get_contents("php://input"), true);
$email = trim($data['email'] ?? '');
$rawPassword = $data['password'] ?? '';

if ($email === '' || $rawPassword === '') {
    echo json_encode([
        'success' => false,
        'message' => 'Email and password are required.',
    ]);
    exit;
}

$password = password_hash($rawPassword, PASSWORD_DEFAULT);
$code = strval(rand(100000, 999999));
$expires = date("Y-m-d H:i:s", strtotime("+10 minutes"));

// Check if account already exists
$check = $conn->prepare("SELECT account_id, is_verified FROM accounts WHERE email_address = ? LIMIT 1");
$check->bind_param('s', $email);
$check->execute();
$existing = $check->get_result()->fetch_assoc();

$linkedExisting = false;

if ($existing) {
    if ((int) $existing['is_verified'] === 1) {
        echo json_encode([
            'success' => false,
            'message' => 'Account already verified. Please log in.',
        ]);
        exit;
    }

    // Update existing unverified account with new code/password
    $update = $conn->prepare("
        UPDATE accounts
        SET password_hash = ?,
            verification_code = ?,
            verification_expires = ?,
            account_type = 'mother'
        WHERE email_address = ?
    ");
    $update->bind_param('ssss', $password, $code, $expires, $email);
    if (!$update->execute()) {
        echo json_encode([
            'success' => false,
            'message' => 'Unable to update account.',
        ]);
        exit;
    }
    $linkedExisting = true;
} else {
    // Create new account
    $stmt = $conn->prepare("
        INSERT INTO accounts
        (email_address, password_hash, account_type, verification_code, verification_expires)
        VALUES (?, ?, 'mother', ?, ?)
    ");
    $stmt->bind_param("ssss", $email, $password, $code, $expires);

    if (!$stmt->execute()) {
        echo json_encode([
            'success' => false,
            'message' => 'Registration failed. Please try again.',
        ]);
        exit;
    }
}

$mailSent = sendMail($email, "Verification Code", "Your code is: $code");

if (!$mailSent) {
    echo json_encode([
        'success' => false,
        'message' => 'Failed to send verification email. Please retry.',
    ]);
    exit;
}

echo json_encode([
    'success' => true,
    'linked_existing' => $linkedExisting,
    'message' => 'Verification code sent to your email.',
]);
