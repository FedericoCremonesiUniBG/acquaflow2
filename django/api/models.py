from django.db import models


DISTRETTO_CHOICES = [
    ('Nord-Ovest BG', 'Nord-Ovest BG'),
    ('Sud-Est BG e BS', 'Sud-Est BG e BS'),
    ('Brianza', 'Brianza'),
    ('Lecchese e Lario', 'Lecchese e Lario'),
    ('Martesana e Cremasco', 'Martesana e Cremasco'),
    ('Non Definito', 'Non Definito'),
]

STATO_UTENZA_CHOICES = [
    ('attiva', 'attiva'),
    ('inattiva', 'inattiva'),
]

TIPOLOGIA_UTENZA_CHOICES = [
    ('Domestico Residente', 'Domestico Residente'),
    ('Domestico Non Residente', 'Domestico Non Residente'),
    ('Commerciale', 'Commerciale'),
    ('Industriale', 'Industriale'),
]

STATO_PAGAMENTO_CHOICES = [
    ('Annullata', 'Annullata'),
    ('Pagata', 'Pagata'),
    ('Scaduta', 'Scaduta'),
]

TIPO_LETTURA_CHOICES = [
    ('reale', 'reale'),
    ('stimata', 'stimata'),
    ('autolettura', 'autolettura'),
]


class Cliente(models.Model):
    codice = models.CharField(max_length=50, primary_key=True)
    cf_piva = models.CharField(max_length=16, unique=True)
    rag_soc = models.CharField(max_length=100)
    indirizzo = models.CharField(max_length=150, null=True, blank=True)
    citta = models.CharField(max_length=100, null=True, blank=True)

    class Meta:
        managed = False
        db_table = 'cliente'

    def __str__(self):
        return self.codice


class PuntoFornitura(models.Model):
    codice_pod = models.CharField(max_length=50, primary_key=True)
    indirizzo = models.CharField(max_length=150, null=True, blank=True)
    citta = models.CharField(max_length=100, null=True, blank=True)
    distretto = models.CharField(max_length=30, choices=DISTRETTO_CHOICES, default='Non Definito')
    diametro_tubo = models.CharField(max_length=20, null=True, blank=True)
    portata_massima = models.CharField(max_length=20, null=True, blank=True)

    class Meta:
        managed = False
        db_table = 'puntofornitura'

    def __str__(self):
        return self.codice_pod


class Utenza(models.Model):
    codice = models.CharField(max_length=50, primary_key=True)
    codice_parlante = models.CharField(max_length=50, unique=True, null=True, blank=True)
    codice_pod = models.ForeignKey(
        PuntoFornitura, db_column='codice_pod', on_delete=models.SET_NULL,
        null=True, blank=True, related_name='utenze'
    )
    cliente = models.ForeignKey(
        Cliente, db_column='cliente', on_delete=models.CASCADE,
        null=True, blank=True, related_name='utenze'
    )
    data_apertura = models.DateField(null=True, blank=True)
    stato = models.CharField(max_length=10, choices=STATO_UTENZA_CHOICES, default='attiva')
    data_chiusura = models.DateField(null=True, blank=True)
    tipologia = models.CharField(max_length=30, choices=TIPOLOGIA_UTENZA_CHOICES)
    componenti_nucleo = models.IntegerField(null=True, blank=True)
    indirizzo_fatturazione = models.CharField(max_length=150, null=True, blank=True)
    citta_fatturazione = models.CharField(max_length=100, null=True, blank=True)

    class Meta:
        managed = False
        db_table = 'utenza'

    def __str__(self):
        return self.codice


class Fattura(models.Model):
    codice = models.CharField(max_length=50, primary_key=True)
    codice_parlante = models.CharField(max_length=50, unique=True, null=True, blank=True)
    utenza = models.ForeignKey(
        Utenza, db_column='utenza', on_delete=models.SET_NULL,
        null=True, blank=True, related_name='fatture'
    )
    cliente = models.ForeignKey(
        Cliente, db_column='cliente', on_delete=models.CASCADE,
        null=True, blank=True, related_name='fatture'
    )
    data = models.DateField()
    imponibile = models.DecimalField(max_digits=10, decimal_places=2)
    iva = models.DecimalField(max_digits=10, decimal_places=2)
    totale = models.DecimalField(max_digits=10, decimal_places=2)
    data_scadenza = models.DateField(null=True, blank=True)
    stato_pagamento = models.CharField(max_length=15, choices=STATO_PAGAMENTO_CHOICES, default='Annullata')
    data_pagamento = models.DateField(null=True, blank=True)
    indirizzo_fatturazione = models.CharField(max_length=150, null=True, blank=True)
    citta_fatturazione = models.CharField(max_length=100, null=True, blank=True)

    class Meta:
        managed = False
        db_table = 'fattura'

    def __str__(self):
        return self.codice


class Lettura(models.Model):
    codice = models.CharField(max_length=50, primary_key=True)
    codice_parlante = models.CharField(max_length=50, unique=True, null=True, blank=True)
    utenza = models.ForeignKey(
        Utenza, db_column='utenza', on_delete=models.CASCADE,
        null=True, blank=True, related_name='letture'
    )
    fattura = models.ForeignKey(
        Fattura, db_column='fattura', on_delete=models.SET_NULL,
        null=True, blank=True, related_name='letture'
    )
    data = models.DateField()
    valore = models.IntegerField()
    tipo_lettura = models.CharField(max_length=15, choices=TIPO_LETTURA_CHOICES, default='reale')

    class Meta:
        managed = False
        db_table = 'lettura'

    def __str__(self):
        return self.codice
