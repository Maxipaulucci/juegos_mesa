package com.juegosmesa.sala.util;

import java.security.SecureRandom;

public final class CodigoGenerator {

    private static final String LETTERS = "ABCDEFGHJKLMNPQRSTUVWXYZ";
    private static final String DIGITS = "23456789";
    private static final String CHARS = LETTERS + DIGITS;
    private static final SecureRandom RNG = new SecureRandom();

    private CodigoGenerator() {}

    public static String generar(int largo) {
        var chars = new char[largo];
        var bytes = new byte[largo];
        RNG.nextBytes(bytes);
        for (var i = 0; i < largo; i++) {
            chars[i] = CHARS.charAt(bytes[i] & 0xFF % CHARS.length());
        }
        var hasLetter = false;
        var hasDigit = false;
        for (var c : chars) {
            if (LETTERS.indexOf(c) >= 0) hasLetter = true;
            if (DIGITS.indexOf(c) >= 0) hasDigit = true;
        }
        if (!hasLetter) {
            chars[bytes[0] & 0xFF % largo] = LETTERS.charAt(bytes[1] & 0xFF % LETTERS.length());
        }
        if (!hasDigit) {
            var idx = (bytes[0] + 1) & 0xFF % largo;
            chars[idx] = DIGITS.charAt(bytes[2] & 0xFF % DIGITS.length());
        }
        return new String(chars);
    }

    public static boolean codigoValido(String codigo) {
        return codigo != null && codigo.matches("^[A-Za-z0-9]{6}$");
    }

    public static String nuevoId(String prefix) {
        var bytes = new byte[6];
        RNG.nextBytes(bytes);
        var hex = new StringBuilder();
        for (var b : bytes) {
            hex.append(String.format("%02x", b));
        }
        return prefix + "-" + hex;
    }
}
