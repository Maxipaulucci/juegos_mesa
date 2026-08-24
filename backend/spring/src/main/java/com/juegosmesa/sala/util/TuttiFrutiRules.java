package com.juegosmesa.sala.util;

import java.util.Map;

public final class TuttiFrutiRules {

    private static final Map<String, Integer> FASE_ORDEN = Map.of(
            "countdownRuleta", 0,
            "ruleta", 1,
            "countdownEscritura", 2,
            "escritura", 3,
            "countdownRevision", 4,
            "revision", 5,
            "fin", 6
    );

    private TuttiFrutiRules() {}

    @SuppressWarnings("unchecked")
    public static boolean faseRegresa(Map<String, Object> prev, Map<String, Object> next) {
        if (prev == null || next == null) return false;
        if (!"tutiFruti".equals(prev.get("juego")) || !"tutiFruti".equals(next.get("juego"))) {
            return false;
        }
        var prevRonda = toInt(prev.get("ronda"), 1);
        var nextRonda = toInt(next.get("ronda"), 1);
        if (nextRonda < prevRonda) return true;
        if (nextRonda > prevRonda) return false;
        var prevOrden = FASE_ORDEN.getOrDefault(String.valueOf(prev.get("fase")), 0);
        var nextOrden = FASE_ORDEN.getOrDefault(String.valueOf(next.get("fase")), 0);
        return nextOrden < prevOrden;
    }

    @SuppressWarnings("unchecked")
    public static boolean bastaPisado(Map<String, Object> prev, Map<String, Object> next) {
        if (prev == null || next == null) return false;
        if (!"tutiFruti".equals(prev.get("juego")) || !"tutiFruti".equals(next.get("juego"))) {
            return false;
        }
        if (!Boolean.TRUE.equals(prev.get("bastaTodos")) || Boolean.TRUE.equals(next.get("bastaTodos"))) {
            return false;
        }
        var prevRonda = toInt(prev.get("ronda"), 1);
        var nextRonda = toInt(next.get("ronda"), 1);
        if (nextRonda != prevRonda) return false;
        return "escritura".equals(prev.get("fase")) && "escritura".equals(next.get("fase"));
    }

    private static int toInt(Object value, int fallback) {
        if (value instanceof Number n) return n.intValue();
        try {
            return Integer.parseInt(String.valueOf(value));
        } catch (Exception e) {
            return fallback;
        }
    }
}
