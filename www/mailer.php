<?php
use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\Exception;

require 'PHPMailer/src/Exception.php';
require 'PHPMailer/src/PHPMailer.php';
require 'PHPMailer/src/SMTP.php';

function sendMail($to, $subject, $message)
{
    $mail = new PHPMailer(true);

    try {
        // 🔐 SMTP CONFIG
        $mail->isSMTP();
        $mail->Host = 'smtp.gmail.com';
        $mail->SMTPAuth = true;
        $mail->Username = 'inaagapay.official@gmail.com';
        $mail->Password = 'rutq gsjd qawb wihi';
        $mail->SMTPSecure = PHPMailer::ENCRYPTION_STARTTLS;
        $mail->Port = 587;

        // ✉️ EMAIL HEADERS
        $mail->setFrom('inaagapay.official@gmail.com', 'InaAgapay');
        $mail->addAddress($to);

        // 📩 EMAIL CONTENT
        $mail->isHTML(true);
        $mail->Subject = $subject;
        $mail->Body = "
            <div style='font-family: Arial, sans-serif'>
                <h2>$subject</h2>
                <p>$message</p>
                <br>
                <small>InaAgapay Health System</small>
            </div>
        ";

        $mail->AltBody = $message;

        $mail->send();
        return true;

    } catch (Exception $e) {
        error_log('MAIL ERROR: ' . $mail->ErrorInfo);
        return false;
    }
}