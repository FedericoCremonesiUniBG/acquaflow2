<?php
// /php/config/database.php

class Database {

    public $conn;

    public function getConnection() {
        $this->conn = null;
        $credenziali = require __DIR__ . '/credentials.php';

        try {
            $this->conn = new PDO(
                "mysql:host=" . $credenziali["host"] . ";dbname=" . $credenziali["db_name"],
                $credenziali["username"],
                $credenziali["password"]
            );
            $this->conn->exec("set names utf8");
            $this->conn->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
            $this->conn->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);
        } catch(PDOException $exception) {
            http_response_code(500);
            echo json_encode(["message" => "Errore di connessione al database."]);
            exit;
        }

        return $this->conn;
    }
}
?>
