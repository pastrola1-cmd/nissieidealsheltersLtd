<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(["status" => "error", "message" => "Method not allowed"]);
    exit();
}

$input = file_get_contents('php://input');
$data = json_decode($input, true);

if (!$data) {
    http_response_code(400);
    echo json_encode(["status" => "error", "message" => "Invalid JSON payload"]);
    exit();
}

// Required fields
$required = ['smtp_host', 'smtp_port', 'smtp_username', 'smtp_password', 'to_email', 'subject', 'body', 'from_email'];
foreach ($required as $field) {
    if (empty($data[$field])) {
        http_response_code(400);
        echo json_encode(["status" => "error", "message" => "Missing required field: $field"]);
        exit();
    }
}

$host = $data['smtp_host'];
$port = intval($data['smtp_port']);
$username = $data['smtp_username'];
$password = $data['smtp_password'];
$toEmail = $data['to_email'];
$toName = isset($data['to_name']) ? $data['to_name'] : '';
$subject = $data['subject'];
$body = $data['body'];
$fromEmail = $data['from_email'];
$fromName = isset($data['from_name']) ? $data['from_name'] : '';

// Function to communicate with SMTP server
function sendSmtpMail($host, $port, $username, $password, $fromEmail, $fromName, $toEmail, $toName, $subject, $body) {
    $timeout = 15;
    
    // Connect to SMTP Server
    // If SSL is used (usually port 465), prepend ssl:// to host
    $socketHost = ($port === 465) ? "ssl://" . $host : $host;
    $socket = @fsockopen($socketHost, $port, $errno, $errstr, $timeout);
    
    if (!$socket) {
        return ["success" => false, "error" => "Connection failed: $errstr ($errno)"];
    }

    function readResponse($socket, $expectedCode) {
        $response = "";
        while ($line = fgets($socket, 515)) {
            $response .= $line;
            if (substr($line, 3, 1) === " ") {
                break;
            }
        }
        $code = intval(substr($response, 0, 3));
        if ($code !== $expectedCode) {
            return ["success" => false, "error" => "Expected code $expectedCode, got: " . trim($response)];
        }
        return ["success" => true, "data" => $response];
    }

    // Read welcome message
    $res = readResponse($socket, 220);
    if (!$res['success']) return $res;

    // Send EHLO
    fputs($socket, "EHLO " . $_SERVER['SERVER_NAME'] . "\r\n");
    $res = readResponse($socket, 250);
    if (!$res['success']) return $res;

    // Handle STARTTLS for port 587
    if ($port === 587) {
        fputs($socket, "STARTTLS\r\n");
        $res = readResponse($socket, 220);
        if (!$res['success']) return $res;

        // Upgrade socket connection to TLS
        if (!stream_socket_enable_crypto($socket, true, STREAM_CRYPTO_METHOD_TLS_CLIENT)) {
            return ["success" => false, "error" => "TLS encryption hand-shake failed"];
        }

        // Send EHLO again under TLS
        fputs($socket, "EHLO " . $_SERVER['SERVER_NAME'] . "\r\n");
        $res = readResponse($socket, 250);
        if (!$res['success']) return $res;
    }

    // Authenticate
    fputs($socket, "AUTH LOGIN\r\n");
    $res = readResponse($socket, 334);
    if (!$res['success']) return $res;

    fputs($socket, base64_encode($username) . "\r\n");
    $res = readResponse($socket, 334);
    if (!$res['success']) return $res;

    fputs($socket, base64_encode($password) . "\r\n");
    $res = readResponse($socket, 235);
    if (!$res['success']) return $res;

    // Mail from
    fputs($socket, "MAIL FROM:<" . $fromEmail . ">\r\n");
    $res = readResponse($socket, 250);
    if (!$res['success']) return $res;

    // Recipient to
    fputs($socket, "RCPT TO:<" . $toEmail . ">\r\n");
    $res = readResponse($socket, 250);
    if (!$res['success']) return $res;

    // Data
    fputs($socket, "DATA\r\n");
    $res = readResponse($socket, 354);
    if (!$res['success']) return $res;

    // Prepare headers and body content
    $headers = [
        "MIME-Version: 1.0",
        "Content-Type: text/html; charset=UTF-8",
        "From: " . ($fromName ? "=?UTF-8?B?" . base64_encode($fromName) . "?=" : "") . " <" . $fromEmail . ">",
        "To: " . ($toName ? "=?UTF-8?B?" . base64_encode($toName) . "?=" : "") . " <" . $toEmail . ">",
        "Subject: =?UTF-8?B?" . base64_encode($subject) . "?=",
        "Date: " . date('r'),
        "Message-ID: <" . uniqid() . "@" . $_SERVER['SERVER_NAME'] . ">"
    ];

    $emailData = implode("\r\n", $headers) . "\r\n\r\n" . $body . "\r\n.\r\n";
    fputs($socket, $emailData);
    $res = readResponse($socket, 250);
    if (!$res['success']) return $res;

    // Quit
    fputs($socket, "QUIT\r\n");
    fclose($socket);

    return ["success" => true];
}

$result = sendSmtpMail($host, $port, $username, $password, $fromEmail, $fromName, $toEmail, $toName, $subject, $body);

if ($result['success']) {
    http_response_code(200);
    echo json_encode(["status" => "success", "message" => "Email sent successfully"]);
} else {
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => $result['error']]);
}
