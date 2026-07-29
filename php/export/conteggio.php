<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET");

include_once '../config/database.php';

$database = new Database();
$db = $database->getConnection();

$tabelle = [
    "clienti" => "SELECT COUNT(*) AS totale FROM Cliente",
    "punti_fornitura" => "SELECT COUNT(*) AS totale FROM PuntoFornitura",
    "utenze" => "SELECT COUNT(*) AS totale FROM Utenza",
    "fatture" => "SELECT COUNT(*) AS totale FROM Fattura",
    "letture" => "SELECT COUNT(*) AS totale FROM Lettura"
];

$response = ["success" => true];

try {
    foreach ($tabelle as $chiave => $query) {
        $stmt = $db->query($query);
        $riga = $stmt->fetch();
        $response[$chiave] = (int) $riga['totale'];
    }
    http_response_code(200);
    echo json_encode($response);
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(["success" => false, "message" => $e->getMessage()]);
}
?>
