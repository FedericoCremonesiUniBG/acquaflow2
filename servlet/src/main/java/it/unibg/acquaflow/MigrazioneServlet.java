package it.unibg.acquaflow;

import java.io.IOException;
import java.io.InputStreamReader;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import com.google.gson.Gson;
import com.google.gson.stream.JsonReader;
import com.google.gson.stream.JsonToken;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

@WebServlet("/migra")
public class MigrazioneServlet extends HttpServlet {

    private static final String URL_PHP = "http://distribuzioneacqua2.altervista.org/php/export/dump.php";
    private static final String URL_DJANGO_BASE = "http://127.0.0.1:8000/api/";
    private static final int DIMENSIONE_BLOCCO = 500;

    private static final Map<String, String> ENDPOINT_DJANGO = Map.of(
            "clienti", "clienti/",
            "punti_fornitura", "punti-fornitura/",
            "utenze", "utenze/",
            "fatture", "fatture/",
            "letture", "letture/"
    );

    private static final Map<String, Map<String, String>> RINOMINA_CAMPI = Map.of(
            "clienti", Map.of("ragSoc", "rag_soc", "città", "citta"),
            "punti_fornitura", Map.of("città", "citta"),
            "utenze", Map.of("dataAp", "data_apertura", "dataCh", "data_chiusura", "città_fatturazione", "citta_fatturazione"),
            "fatture", Map.of("città_fatturazione", "citta_fatturazione"),
            "letture", Map.of()
    );

    private final Gson gson = new Gson();
    private final HttpClient client = HttpClient.newHttpClient();

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        response.setContentType("text/plain; charset=UTF-8");
        StringBuilder esito = new StringBuilder();

        HttpRequest richiestaPhp = HttpRequest.newBuilder(URI.create(URL_PHP)).GET().build();

        try {
            HttpResponse<java.io.InputStream> rispostaPhp =
                    client.send(richiestaPhp, HttpResponse.BodyHandlers.ofInputStream());

            try (JsonReader reader = new JsonReader(new InputStreamReader(rispostaPhp.body(), StandardCharsets.UTF_8))) {
                reader.beginObject();
                while (reader.hasNext()) {
                    String nome = reader.nextName();
                    if (nome.equals("success")) {
                        reader.nextBoolean();
                        continue;
                    }
                    int inseriti = migraTabella(nome, reader);
                    esito.append(nome).append(": ").append(inseriti).append(" record migrati\n");
                }
                reader.endObject();
            }
        } catch (Exception e) {
            e.printStackTrace();
            response.setStatus(HttpServletResponse.SC_INTERNAL_SERVER_ERROR);
            response.getWriter().write("Errore durante la migrazione: " + e.getClass().getName() + " - " + e.getMessage());
            return;
        }

        response.getWriter().write(esito.toString());
    }

    private int migraTabella(String nomeTabella, JsonReader reader) throws IOException, InterruptedException {
        Map<String, String> rinomine = RINOMINA_CAMPI.getOrDefault(nomeTabella, Map.of());
        String urlDjango = URL_DJANGO_BASE + ENDPOINT_DJANGO.get(nomeTabella);

        List<Map<String, Object>> blocco = new ArrayList<>();
        int totaleInseriti = 0;

        reader.beginArray();
        while (reader.hasNext()) {
            blocco.add(leggiRecord(reader, rinomine));

            if (blocco.size() >= DIMENSIONE_BLOCCO) {
                inviaBlocco(urlDjango, blocco);
                totaleInseriti += blocco.size();
                blocco.clear();
            }
        }
        reader.endArray();

        if (!blocco.isEmpty()) {
            inviaBlocco(urlDjango, blocco);
            totaleInseriti += blocco.size();
        }

        return totaleInseriti;
    }

    private Map<String, Object> leggiRecord(JsonReader reader, Map<String, String> rinomine) throws IOException {
        Map<String, Object> record = new LinkedHashMap<>();
        reader.beginObject();
        while (reader.hasNext()) {
            String campo = reader.nextName();
            String campoFinale = rinomine.getOrDefault(campo, campo);
            record.put(campoFinale, leggiValore(reader));
        }
        reader.endObject();
        return record;
    }

    private Object leggiValore(JsonReader reader) throws IOException {
        if (reader.peek() == JsonToken.NULL) {
            reader.nextNull();
            return null;
        }
        return reader.nextString();
    }

    private void inviaBlocco(String url, List<Map<String, Object>> blocco) throws IOException, InterruptedException {
        String corpoJson = gson.toJson(blocco);
        HttpRequest richiesta = HttpRequest.newBuilder(URI.create(url))
                .header("Content-Type", "application/json; charset=UTF-8")
                .POST(HttpRequest.BodyPublishers.ofString(corpoJson, StandardCharsets.UTF_8))
                .build();

        HttpResponse<String> risposta = client.send(richiesta, HttpResponse.BodyHandlers.ofString());
        if (risposta.statusCode() != 200) {
            throw new IOException("Django ha risposto con codice " + risposta.statusCode() + ": " + risposta.body());
        }
    }
}
