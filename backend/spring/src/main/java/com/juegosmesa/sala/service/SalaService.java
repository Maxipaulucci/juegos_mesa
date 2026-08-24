package com.juegosmesa.sala.service;

import com.juegosmesa.sala.model.JugadorEmbedded;
import com.juegosmesa.sala.model.SalaDocument;
import com.juegosmesa.sala.repository.SalaRepository;
import com.juegosmesa.sala.util.CodigoGenerator;
import com.juegosmesa.sala.util.TuttiFrutiRules;
import com.juegosmesa.sala.web.ApiException;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
public class SalaService {

    private static final long TTL_PARTIDA_MS = 60L * 60L * 1000L;
    private static final String SALA_NO_EXISTE =
            "No existe una sala con ese código (o expiró tras 1 hora de juego).";

    private final SalaRepository repository;

    public SalaService(SalaRepository repository) {
        this.repository = repository;
    }

    public Map<String, Object> obtener(String codigoRaw) {
        var codigo = normalizarCodigo(codigoRaw);
        if (codigo.isEmpty()) throw new ApiException(400, "Falta el código.");
        var sala = leerSala(codigo);
        if (sala == null) throw new ApiException(404, SALA_NO_EXISTE);
        return Map.of("sala", sala.toMap());
    }

    public Map<String, Object> post(Map<String, Object> body) {
        var action = str(body.get("action"));
        return switch (action) {
            case "crear" -> crear(body);
            case "unirse" -> unirse(body);
            case "expulsar" -> expulsar(body);
            case "iniciar" -> iniciar(body);
            case "actualizarLobby" -> actualizarLobby(body);
            case "actualizarJuego" -> actualizarJuego(body);
            case "cerrar" -> cerrar(body);
            default -> throw new ApiException(400, "Acción desconocida.");
        };
    }

    private Map<String, Object> crear(Map<String, Object> body) {
        var juegoId = str(body.get("juegoId"));
        var nombre = str(body.get("nombre"));
        if (juegoId.isEmpty()) throw new ApiException(400, "Falta el juego.");
        if (nombre.isEmpty()) throw new ApiException(400, "Escribí tu nombre.");

        var codigo = codigoLibre();
        var anfitrionId = CodigoGenerator.nuevoId("host");
        var sala = new SalaDocument();
        sala.setCodigo(codigo);
        sala.setJuegoId(juegoId);
        sala.setAnfitrionId(anfitrionId);
        sala.setEstado("lobby");
        sala.setDados(5);
        sala.setCreadaEn(System.currentTimeMillis());
        sala.setJugadores(new ArrayList<>(List.of(
                new JugadorEmbedded(anfitrionId, nombre, "anfitrion")
        )));
        if ("tutiFruti".equals(juegoId)) {
            sala.setLobbyCategorias(new ArrayList<>(List.of("Nombre", "Animal", "Color")));
            sala.setLobbyMaxRondas(5);
        } else {
            sala.setLobbyCategorias(new ArrayList<>());
            sala.setLobbyMaxRondas(null);
        }
        repository.save(sala);
        return Map.of("sala", sala.toMap(), "miId", anfitrionId);
    }

    private Map<String, Object> unirse(Map<String, Object> body) {
        var codigo = normalizarCodigo(body.get("codigo"));
        var nombre = str(body.get("nombre"));
        var juegoId = str(body.get("juegoId"));
        if (codigo.isEmpty()) throw new ApiException(400, "Ingresá el código de la sala.");
        if (!CodigoGenerator.codigoValido(codigo)) {
            throw new ApiException(400,
                    "El código debe tener exactamente 6 caracteres y solo letras o números.");
        }
        if (nombre.isEmpty()) throw new ApiException(400, "Escribí tu nombre.");

        var sala = leerSala(codigo);
        if (sala == null) throw new ApiException(404, SALA_NO_EXISTE);
        if (!"lobby".equals(sala.getEstado())) {
            throw new ApiException(409, "La partida ya empezó.");
        }
        if (!juegoId.isEmpty() && !juegoId.equals(sala.getJuegoId())) {
            throw new ApiException(409, "Esa sala es de otro juego.");
        }
        if (sala.getJugadores().stream().anyMatch(j ->
                j.getNombre().equalsIgnoreCase(nombre))) {
            throw new ApiException(409, "Ese nombre ya está en la sala.");
        }
        if (sala.getJugadores().size() >= 4) {
            throw new ApiException(409, "La sala está llena (máx. 4).");
        }

        var miId = CodigoGenerator.nuevoId("p");
        sala.getJugadores().add(new JugadorEmbedded(miId, nombre, "invitado"));
        repository.save(sala);
        return Map.of("sala", sala.toMap(), "miId", miId);
    }

    private Map<String, Object> expulsar(Map<String, Object> body) {
        var codigo = normalizarCodigo(body.get("codigo"));
        var anfitrionId = str(body.get("anfitrionId"));
        var jugadorId = str(body.get("jugadorId"));
        var sala = requireSala(codigo);
        if (!anfitrionId.equals(sala.getAnfitrionId())) {
            throw new ApiException(403, "Solo el anfitrión puede expulsar.");
        }
        if (jugadorId.equals(sala.getAnfitrionId())) {
            throw new ApiException(400, "No podés expulsar al anfitrión.");
        }
        sala.setJugadores(sala.getJugadores().stream()
                .filter(j -> !jugadorId.equals(j.getId()))
                .collect(Collectors.toCollection(ArrayList::new)));
        repository.save(sala);
        return Map.of("sala", sala.toMap());
    }

    private Map<String, Object> iniciar(Map<String, Object> body) {
        var codigo = normalizarCodigo(body.get("codigo"));
        var anfitrionId = str(body.get("anfitrionId"));
        var dados = toInt(body.get("dados"), 5) == 6 ? 6 : 5;
        var sala = requireSala(codigo);
        if (!anfitrionId.equals(sala.getAnfitrionId())) {
            throw new ApiException(403, "Solo el anfitrión puede iniciar.");
        }
        if (sala.getJugadores().size() < 2) {
            throw new ApiException(400, "Hacen falta al menos 2 jugadores.");
        }
        var nombres = sala.getJugadores().stream().map(JugadorEmbedded::getNombre).toList();
        sala.setEstado("jugando");
        sala.setDados(dados);
        sala.setIniciadaEn(System.currentTimeMillis());
        sala.setGameState(GameStateFactory.crearInicial(sala.getJuegoId(), nombres, dados, body));
        repository.save(sala);
        return Map.of("sala", sala.toMap());
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> actualizarLobby(Map<String, Object> body) {
        var codigo = normalizarCodigo(body.get("codigo"));
        var anfitrionId = str(body.get("anfitrionId"));
        var sala = requireSala(codigo);
        if (!anfitrionId.equals(sala.getAnfitrionId())) {
            throw new ApiException(403, "Solo el anfitrión puede editar la sala.");
        }
        if (!"lobby".equals(sala.getEstado())) {
            throw new ApiException(409, "La partida ya empezó.");
        }
        var rawCats = body.get("categorias");
        var cats = new ArrayList<String>();
        if (rawCats instanceof List<?> list) {
            for (var item : list) {
                var c = str(item).trim();
                if (!c.isEmpty()) {
                    cats.add(c.length() > 25 ? c.substring(0, 25) : c);
                }
            }
        }
        if (cats.size() > 6) cats = new ArrayList<>(cats.subList(0, 6));
        var maxRondas = toInt(body.get("maxRondas"), 5);
        maxRondas = Math.max(1, Math.min(26, maxRondas));
        sala.setLobbyCategorias(cats);
        sala.setLobbyMaxRondas(maxRondas);
        repository.save(sala);
        return Map.of("sala", sala.toMap());
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> actualizarJuego(Map<String, Object> body) {
        var codigo = normalizarCodigo(body.get("codigo"));
        if (codigo.isEmpty()) throw new ApiException(400, "Falta el código.");
        var gameState = body.get("gameState");
        if (!(gameState instanceof Map<?, ?> gs)) {
            throw new ApiException(400, "Falta el estado de juego.");
        }
        var sala = requireSala(codigo);
        if (!"jugando".equals(sala.getEstado())) {
            throw new ApiException(409, "La partida no está en curso.");
        }
        var nuevo = (Map<String, Object>) gs;
        var actual = versionOf(sala.getGameState());
        var nueva = versionOf(nuevo);
        if (nueva <= actual) {
            return respuestaIgnorada(sala);
        }
        if (TuttiFrutiRules.faseRegresa(sala.getGameState(), nuevo)) {
            return respuestaIgnorada(sala);
        }
        if (TuttiFrutiRules.bastaPisado(sala.getGameState(), nuevo)) {
            return respuestaIgnorada(sala);
        }
        sala.setGameState(nuevo);
        if (Boolean.TRUE.equals(nuevo.get("mostrarVictoria"))) {
            sala.setEstado("terminada");
        }
        repository.save(sala);
        var resp = new LinkedHashMap<String, Object>();
        resp.put("sala", sala.toMap());
        return resp;
    }

    private Map<String, Object> cerrar(Map<String, Object> body) {
        var codigo = normalizarCodigo(body.get("codigo"));
        var anfitrionId = str(body.get("anfitrionId"));
        var sala = requireSala(codigo);
        if (!anfitrionId.equals(sala.getAnfitrionId())) {
            throw new ApiException(403, "Solo el anfitrión puede cerrar la sala.");
        }
        repository.deleteById(codigo);
        return Map.of("ok", true);
    }

    private Map<String, Object> respuestaIgnorada(SalaDocument sala) {
        var resp = new LinkedHashMap<String, Object>();
        resp.put("sala", sala.toMap());
        resp.put("ignored", true);
        return resp;
    }

    private SalaDocument requireSala(String codigo) {
        var sala = leerSala(codigo);
        if (sala == null) throw new ApiException(404, SALA_NO_EXISTE);
        return sala;
    }

    private SalaDocument leerSala(String codigo) {
        var sala = repository.findById(codigo).orElse(null);
        if (sala == null) return null;
        if (partidaExpirada(sala)) {
            repository.deleteById(codigo);
            return null;
        }
        return sala;
    }

    private boolean partidaExpirada(SalaDocument sala) {
        if (sala.getIniciadaEn() == null) return false;
        return System.currentTimeMillis() - sala.getIniciadaEn() >= TTL_PARTIDA_MS;
    }

    private String codigoLibre() {
        for (var i = 0; i < 24; i++) {
            var codigo = CodigoGenerator.generar(6);
            var existente = repository.findById(codigo).orElse(null);
            if (existente == null) return codigo;
            if (partidaExpirada(existente)) {
                repository.deleteById(codigo);
                return codigo;
            }
        }
        throw new ApiException(500, "No se pudo generar un código libre. Reintentá.");
    }

    private static int versionOf(Map<String, Object> gameState) {
        if (gameState == null) return 0;
        return toInt(gameState.get("version"), 0);
    }

    private static String normalizarCodigo(Object raw) {
        return str(raw).trim().toUpperCase();
    }

    private static String str(Object raw) {
        return raw == null ? "" : String.valueOf(raw).trim();
    }

    private static int toInt(Object value, int fallback) {
        if (value instanceof Number n) return n.intValue();
        try {
            return (int) Math.floor(Double.parseDouble(String.valueOf(value)));
        } catch (Exception e) {
            return fallback;
        }
    }
}
