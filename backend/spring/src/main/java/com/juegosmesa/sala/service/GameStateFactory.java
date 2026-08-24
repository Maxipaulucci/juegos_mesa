package com.juegosmesa.sala.service;

import com.juegosmesa.sala.web.ApiException;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public final class GameStateFactory {

    private GameStateFactory() {}

    @SuppressWarnings("unchecked")
    public static Map<String, Object> crearInicial(
            String juegoId,
            List<String> nombres,
            int dados,
            Map<String, Object> body
    ) {
        return switch (juegoId) {
            case "tutiFruti" -> tutiFruti(nombres, body);
            case "generala" -> generala(nombres);
            case "laPapa" -> laPapa(nombres, body);
            case "escobaDel15" -> escobaDel15(nombres);
            case "unoSolo" -> unoSolo(nombres);
            case "culoSucioV1" -> culoSucioV1(nombres);
            case "culoSucioV2" -> culoSucioV2(nombres);
            case "chanchoVa" -> chanchoVa(nombres, body);
            case "casitaRobada" -> casitaRobada(nombres);
            default -> diezMil(nombres, dados);
        };
    }

    private static Map<String, Object> tutiFruti(List<String> nombres, Map<String, Object> body) {
        var rawCats = body.get("categorias");
        var cats = new ArrayList<String>();
        if (rawCats instanceof List<?> list) {
            for (var item : list) {
                var c = String.valueOf(item == null ? "" : item).trim();
                if (!c.isEmpty()) cats.add(c);
            }
        }
        if (cats.size() < 3 || cats.size() > 6) {
            throw new ApiException(400, "Tutti Frutti: entre 3 y 6 categorías.");
        }
        for (var c : cats) {
            if (c.length() > 25) {
                throw new ApiException(400, "Cada categoría puede tener hasta 25 caracteres.");
            }
        }
        var maxRondas = toInt(body.get("maxRondas"), 5);
        if (maxRondas < 1 || maxRondas > 26) {
            throw new ApiException(400, "Tutti Frutti: rondas entre 1 y 26 (abecedario).");
        }
        var respuestas = new LinkedHashMap<String, Object>();
        var listos = new LinkedHashMap<String, Object>();
        var puntajes = new LinkedHashMap<String, Object>();
        var totales = new LinkedHashMap<String, Object>();
        for (var n : nombres) {
            respuestas.put(n, cats.stream().map(c -> "").toList());
            listos.put(n, false);
            puntajes.put(n, cats.stream().map(c -> (Object) null).toList());
            totales.put(n, 0);
        }
        var state = baseState("tutiFruti");
        state.put("categorias", cats);
        state.put("nombres", nombres);
        state.put("fase", "countdownRuleta");
        state.put("indiceSpinner", 0);
        state.put("ronda", 1);
        state.put("maxRondas", maxRondas);
        state.put("letra", null);
        state.put("letrasUsadas", List.of());
        state.put("ruletaInicioMs", null);
        state.put("ruletaVelocidad", 8);
        state.put("faseInicioMs", System.currentTimeMillis());
        state.put("respuestas", respuestas);
        state.put("listos", listos);
        state.put("bastaTodos", false);
        state.put("bastaInicioMs", null);
        state.put("bastaPor", null);
        state.put("categoriaRevision", 0);
        state.put("puntajes", puntajes);
        state.put("totales", totales);
        state.put("mostrarVictoria", false);
        return state;
    }

    private static Map<String, Object> generala(List<String> nombres) {
        var cats = List.of(
                "1", "2", "3", "4", "5", "6",
                "ESCALERA", "FULL", "POKER", "GENERALA", "GENERALA DOBLE"
        );
        var jugadores = new ArrayList<Map<String, Object>>();
        for (var n : nombres) {
            var casillas = new LinkedHashMap<String, Object>();
            for (var c : cats) casillas.put(c, null);
            var jugador = new LinkedHashMap<String, Object>();
            jugador.put("nombre", n);
            jugador.put("rendido", false);
            jugador.put("casillas", casillas);
            jugadores.add(jugador);
        }
        var state = baseState("generala");
        state.put("indiceTurno", 0);
        state.put("ganador", null);
        state.put("jugadores", jugadores);
        state.put("turno", Map.of(
                "dados", List.of(),
                "guardados", List.of(false, false, false, false, false),
                "tiradasHechas", 0
        ));
        state.put("modoAnotar", false);
        state.put("mostrarVictoria", false);
        return state;
    }

    @SuppressWarnings("unchecked")
    private static Map<String, Object> laPapa(List<String> nombres, Map<String, Object> body) {
        var opts = body.get("opcionesPapa") instanceof Map<?, ?> m
                ? (Map<String, Object>) m
                : Map.<String, Object>of();
        var modoFantasma = Boolean.TRUE.equals(opts.get("modoFantasma"));
        var conVidas = !modoFantasma && Boolean.TRUE.equals(opts.get("conVidas"));
        var cantidad = toInt(opts.get("cantidadNumeros"), 30);
        if (modoFantasma) cantidad = 50;
        cantidad = Math.max(2, Math.min(50, cantidad));
        var vidas = conVidas ? nombres.stream().map(n -> 3).toList() : List.<Integer>of();
        var aleatorios = modoFantasma || !Boolean.FALSE.equals(opts.get("numerosAleatorios"));
        var state = baseState("laPapa");
        state.put("nombres", nombres);
        state.put("casillas", null);
        state.put("maxNumero", cantidad);
        state.put("indiceTurno", 0);
        state.put("siguienteConectar", 1);
        state.put("siguienteAColocar", 1);
        state.put("fase", aleatorios ? "jugando" : "colocando");
        state.put("mensajeFin", null);
        state.put("ganador", null);
        state.put("conVidas", conVidas);
        state.put("modoFantasma", modoFantasma);
        state.put("vidas", vidas);
        state.put("trazos", List.of());
        state.put("trazoFallido", List.of());
        state.put("opciones", Map.of(
                "conVidas", Boolean.TRUE.equals(opts.get("conVidas")),
                "numerosAleatorios", !Boolean.FALSE.equals(opts.get("numerosAleatorios")),
                "cantidadNumeros", cantidad,
                "modoFantasma", modoFantasma,
                "mostrarCuadricula", !Boolean.FALSE.equals(opts.get("mostrarCuadricula"))
        ));
        state.put("mostrarVictoria", false);
        state.put("pendienteTablero", true);
        return state;
    }

    private static Map<String, Object> escobaDel15(List<String> nombres) {
        var jugadores = new ArrayList<Map<String, Object>>();
        for (var n : nombres) {
            jugadores.add(new LinkedHashMap<>(Map.of(
                    "nombre", n,
                    "mano", List.of(),
                    "capturadas", List.of(),
                    "combos", List.of(),
                    "escobasRonda", 0,
                    "puntos", 0,
                    "rendido", false
            )));
        }
        var state = baseState("escobaDel15");
        state.put("pendienteMazo", true);
        state.put("objetivo", 15);
        state.put("indiceTurno", 0);
        state.put("fase", "jugando");
        state.put("ultimaCapturaIdx", null);
        state.put("mensajeFin", null);
        state.put("ganador", null);
        state.put("reiniciarCombosEnProximaJugada", false);
        state.put("mazo", List.of());
        state.put("mesa", List.of());
        state.put("jugadores", jugadores);
        state.put("ultimoResultado", null);
        state.put("ultimaJugada", null);
        state.put("mostrarVictoria", false);
        return state;
    }

    private static Map<String, Object> unoSolo(List<String> nombres) {
        var state = baseState("unoSolo");
        state.put("pendienteTablero", true);
        state.put("nombres", nombres);
        state.put("celdas", null);
        state.put("indiceTurno", 0);
        state.put("fase", "jugando");
        state.put("mensajeFin", null);
        state.put("ganador", null);
        state.put("solo", false);
        state.put("mostrarVictoria", false);
        return state;
    }

    private static Map<String, Object> culoSucioV1(List<String> nombres) {
        var state = baseState("culoSucioV1");
        state.put("pendienteMazo", true);
        state.put("comodines", false);
        state.put("nombres", nombres);
        state.put("indiceTurno", 0);
        state.put("fase", "jugando");
        state.put("mazo", List.of());
        state.put("ultimaCarta", null);
        state.put("cartasSacadas", 0);
        state.put("perdedor", null);
        state.put("ganador", null);
        state.put("mensajeFin", null);
        state.put("historial", List.of());
        state.put("mostrarVictoria", false);
        return state;
    }

    private static Map<String, Object> culoSucioV2(List<String> nombres) {
        var jugadores = new ArrayList<Map<String, Object>>();
        for (var n : nombres) {
            jugadores.add(new LinkedHashMap<>(Map.of(
                    "nombre", n,
                    "mano", List.of(),
                    "descartes", List.of(),
                    "paresInicialesListos", false
            )));
        }
        var state = baseState("culoSucioV2");
        state.put("pendienteMazo", true);
        state.put("indiceTurno", 0);
        state.put("fase", "descartandoPares");
        state.put("perdedor", null);
        state.put("ganador", null);
        state.put("mensajeFin", null);
        state.put("ultimaRobada", null);
        state.put("ultimaRobadaDe", null);
        state.put("ultimaRobadaPor", null);
        state.put("ultimoPar", null);
        state.put("eliminarParesAuto", true);
        state.put("jugadores", jugadores);
        state.put("mostrarVictoria", false);
        return state;
    }

    @SuppressWarnings("unchecked")
    private static Map<String, Object> chanchoVa(List<String> nombres, Map<String, Object> body) {
        var opts = body.get("opcionesChancho") instanceof Map<?, ?> m
                ? (Map<String, Object>) m
                : Map.<String, Object>of();
        var sinEspacio = Boolean.TRUE.equals(opts.get("sinEspacio"));
        var finAlPrimerPerdedor = Boolean.TRUE.equals(opts.get("finAlPrimerPerdedor"));
        var chancha = !Boolean.FALSE.equals(opts.get("chancha"));
        var total = toInt(opts.get("totalJugadores"), 3);
        total = Math.min(4, Math.max(3, total));
        var pcs = Math.min(2, Math.max(1, total - nombres.size()));
        var nombresMesa = new ArrayList<>(nombres);
        for (var i = 0; i < pcs; i++) {
            nombresMesa.add("PC " + (i + 1));
        }
        var jugadores = new ArrayList<Map<String, Object>>();
        for (var n : nombresMesa) {
            jugadores.add(new LinkedHashMap<>(Map.of(
                    "nombre", n,
                    "mano", List.of(),
                    "letras", List.of(),
                    "seleccionPase", List.of(),
                    "seleccionPaseConfirmada", false,
                    "dijoChancho", false,
                    "eliminado", false
            )));
        }
        var state = baseState("chanchoVa");
        state.put("pendienteDeal", true);
        state.put("contraPc", true);
        state.put("sinEspacio", sinEspacio);
        state.put("finAlPrimerPerdedor", finAlPrimerPerdedor);
        state.put("opciones", Map.of(
                "chancha", chancha,
                "sinEspacio", sinEspacio,
                "finAlPrimerPerdedor", finAlPrimerPerdedor,
                "totalJugadores", nombresMesa.size()
        ));
        state.put("indiceTurno", 0);
        state.put("fase", "eligiendoNumeros");
        state.put("numerosEnJuego", List.of());
        state.put("anuncioActual", null);
        state.put("ultimoAnuncio", null);
        state.put("quienAbrioChancho", null);
        state.put("ordenChancho", List.of());
        state.put("yaDijeronChanchaRonda", List.of());
        state.put("historialLetras", List.of());
        state.put("ultimoResumenRonda", null);
        state.put("perdedor", null);
        state.put("ganador", null);
        state.put("mensajeFin", null);
        state.put("quienLanzoChancha", null);
        state.put("objetivoChancha", null);
        state.put("jugadores", jugadores);
        state.put("mostrarVictoria", false);
        return state;
    }

    private static Map<String, Object> casitaRobada(List<String> nombres) {
        var jugadores = new ArrayList<Map<String, Object>>();
        for (var n : nombres) {
            jugadores.add(Map.of(
                    "nombre", n,
                    "mano", List.of(),
                    "pozo", List.of()
            ));
        }
        var state = baseState("casitaRobada");
        state.put("pendienteMazo", true);
        state.put("indiceTurno", 0);
        state.put("fase", "jugando");
        state.put("ganador", null);
        state.put("mensajeFin", null);
        state.put("mazo", List.of());
        state.put("mesa", List.of());
        state.put("jugadores", jugadores);
        state.put("mostrarVictoria", false);
        return state;
    }

    private static Map<String, Object> diezMil(List<String> nombres, int dados) {
        var jugadores = new ArrayList<Map<String, Object>>();
        for (var n : nombres) {
            jugadores.add(Map.of(
                    "nombre", n,
                    "puntos", 0,
                    "abierto", false,
                    "rendido", false
            ));
        }
        var state = baseState("diezMil");
        state.put("modo", dados);
        state.put("indiceTurno", 0);
        state.put("ganador", null);
        state.put("jugadores", jugadores);
        state.put("turno", Map.of(
                "dadosEnMano", dados,
                "puntosTurno", 0,
                "tiradaNro", 0,
                "abiertoEstaRonda", false
        ));
        state.put("mostrarVictoria", false);
        state.put("mensaje", null);
        state.put("ultimaTiradaDados", null);
        state.put("ultimoResumen", null);
        return state;
    }

    private static Map<String, Object> baseState(String juego) {
        var state = new LinkedHashMap<String, Object>();
        state.put("version", 1);
        state.put("juego", juego);
        return state;
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
