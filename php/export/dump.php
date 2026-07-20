<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET");

include_once '../config/database.php';

$database = new Database();
$db = $database->getConnection();
$db->setAttribute(PDO::MYSQL_ATTR_USE_BUFFERED_QUERY, false);

$tabelle = [
    "clienti" => "SELECT * FROM Cliente ORDER BY codice",
    "punti_fornitura" => "SELECT * FROM PuntoFornitura ORDER BY codice_pod",
    "utenze" => "SELECT * FROM Utenza ORDER BY codice",
    "fatture" => "SELECT * FROM Fattura ORDER BY codice",
    "letture" => "SELECT * FROM Lettura ORDER BY codice"
];

http_response_code(200);
echo '{"success":true';

foreach ($tabelle as $chiave => $query) {
    echo ',"' . $chiave . '":[';
    $stmt = $db->query($query);
    $prima_riga = true;
    while ($riga = $stmt->fetch(PDO::FETCH_ASSOC)) {
        if (!$prima_riga) {
            echo ',';
        }
        echo json_encode($riga);
        $prima_riga = false;
    }
    echo ']';
    $stmt = null;
}

echo '}';
?>
