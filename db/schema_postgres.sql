DROP TABLE IF EXISTS Lettura CASCADE;
DROP TABLE IF EXISTS Fattura CASCADE;
DROP TABLE IF EXISTS Utenza CASCADE;
DROP TABLE IF EXISTS PuntoFornitura CASCADE;
DROP TABLE IF EXISTS Cliente CASCADE;

DROP TYPE IF EXISTS distretto_enum CASCADE;
DROP TYPE IF EXISTS stato_utenza_enum CASCADE;
DROP TYPE IF EXISTS tipologia_utenza_enum CASCADE;
DROP TYPE IF EXISTS stato_pagamento_enum CASCADE;
DROP TYPE IF EXISTS tipo_lettura_enum CASCADE;

CREATE TABLE Cliente (
    codice VARCHAR(50) PRIMARY KEY,
    cf_piva VARCHAR(16) UNIQUE NOT NULL,
    rag_soc VARCHAR(100) NOT NULL,
    indirizzo VARCHAR(150),
    citta VARCHAR(100)
);

CREATE TABLE PuntoFornitura (
    codice_pod VARCHAR(50) PRIMARY KEY,
    indirizzo VARCHAR(150),
    citta VARCHAR(100),
    distretto VARCHAR(30) DEFAULT 'Non Definito'
        CHECK (distretto IN ('Nord-Ovest BG', 'Sud-Est BG e BS', 'Brianza', 'Lecchese e Lario', 'Martesana e Cremasco', 'Non Definito')),
    diametro_tubo VARCHAR(20),
    portata_massima VARCHAR(20)
);

CREATE TABLE Utenza (
    codice VARCHAR(50) PRIMARY KEY,
    codice_parlante VARCHAR(50) UNIQUE,
    codice_pod VARCHAR(50),
    cliente VARCHAR(50),
    data_apertura DATE,
    stato VARCHAR(10) DEFAULT 'attiva' CHECK (stato IN ('attiva', 'inattiva')),
    data_chiusura DATE,
    tipologia VARCHAR(30) NOT NULL
        CHECK (tipologia IN ('Domestico Residente', 'Domestico Non Residente', 'Commerciale', 'Industriale')),
    componenti_nucleo INT,
    indirizzo_fatturazione VARCHAR(150),
    citta_fatturazione VARCHAR(100),
    FOREIGN KEY (codice_pod) REFERENCES PuntoFornitura(codice_pod) ON DELETE SET NULL ON UPDATE CASCADE,
    FOREIGN KEY (cliente) REFERENCES Cliente(codice) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Fattura (
    codice VARCHAR(50) PRIMARY KEY,
    codice_parlante VARCHAR(50) UNIQUE,
    utenza VARCHAR(50),
    cliente VARCHAR(50),
    data DATE NOT NULL,
    imponibile NUMERIC(10, 2) NOT NULL,
    iva NUMERIC(10, 2) NOT NULL,
    totale NUMERIC(10, 2) NOT NULL,
    data_scadenza DATE,
    stato_pagamento VARCHAR(15) DEFAULT 'Annullata' CHECK (stato_pagamento IN ('Annullata', 'Pagata', 'Scaduta')),
    data_pagamento DATE,
    indirizzo_fatturazione VARCHAR(150),
    citta_fatturazione VARCHAR(100),
    FOREIGN KEY (utenza) REFERENCES Utenza(codice) ON DELETE SET NULL ON UPDATE CASCADE,
    FOREIGN KEY (cliente) REFERENCES Cliente(codice) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Lettura (
    codice VARCHAR(50) PRIMARY KEY,
    codice_parlante VARCHAR(50) UNIQUE,
    utenza VARCHAR(50),
    fattura VARCHAR(50),
    data DATE NOT NULL,
    valore INT NOT NULL,
    tipo_lettura VARCHAR(15) DEFAULT 'reale' CHECK (tipo_lettura IN ('reale', 'stimata', 'autolettura')),
    FOREIGN KEY (utenza) REFERENCES Utenza(codice) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (fattura) REFERENCES Fattura(codice) ON DELETE SET NULL ON UPDATE CASCADE
);
