package com.juegosmesa.sala.model;

import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Document(collection = "salas")
public class SalaDocument {

    @Id
    private String codigo;
    private String juegoId;
    private String anfitrionId;
    private List<JugadorEmbedded> jugadores = new ArrayList<>();
    private String estado = "lobby";
    private int dados = 5;
    private Long creadaEn;
    private Long iniciadaEn;
    /** Última vez que el anfitrión confirmó estar en el lobby (heartbeat). */
    private Long anfitrionVistoEn;
    private List<String> lobbyCategorias = new ArrayList<>();
    private Integer lobbyMaxRondas;
    private List<String> lobbyOpcionesResumen = new ArrayList<>();
    /** Monedas que cada jugador debe apostar (0 = sin apuesta). */
    private int apuestaMonedas = 0;
    /** Si es true, aparece en el listado de Salas y se puede unir sin código. */
    private boolean publica = false;
    private Map<String, Object> gameState;

    public Map<String, Object> toMap() {
        var map = new LinkedHashMap<String, Object>();
        map.put("codigo", codigo);
        map.put("juegoId", juegoId);
        map.put("anfitrionId", anfitrionId);
        map.put("jugadores", jugadores.stream().map(JugadorEmbedded::toMap).toList());
        map.put("estado", estado);
        map.put("dados", dados);
        map.put("apuestaMonedas", apuestaMonedas);
        map.put("publica", publica);
        if (creadaEn != null) map.put("creadaEn", creadaEn);
        if (iniciadaEn != null) map.put("iniciadaEn", iniciadaEn);
        if (anfitrionVistoEn != null) map.put("anfitrionVistoEn", anfitrionVistoEn);
        map.put("lobbyCategorias", lobbyCategorias != null ? lobbyCategorias : List.of());
        if (lobbyMaxRondas != null) map.put("lobbyMaxRondas", lobbyMaxRondas);
        map.put("lobbyOpcionesResumen",
                lobbyOpcionesResumen != null ? lobbyOpcionesResumen : List.of());
        if (gameState != null) map.put("gameState", gameState);
        return map;
    }

    public String getCodigo() { return codigo; }
    public void setCodigo(String codigo) { this.codigo = codigo; }
    public String getJuegoId() { return juegoId; }
    public void setJuegoId(String juegoId) { this.juegoId = juegoId; }
    public String getAnfitrionId() { return anfitrionId; }
    public void setAnfitrionId(String anfitrionId) { this.anfitrionId = anfitrionId; }
    public List<JugadorEmbedded> getJugadores() { return jugadores; }
    public void setJugadores(List<JugadorEmbedded> jugadores) { this.jugadores = jugadores; }
    public String getEstado() { return estado; }
    public void setEstado(String estado) { this.estado = estado; }
    public int getDados() { return dados; }
    public void setDados(int dados) { this.dados = dados; }
    public Long getCreadaEn() { return creadaEn; }
    public void setCreadaEn(Long creadaEn) { this.creadaEn = creadaEn; }
    public Long getIniciadaEn() { return iniciadaEn; }
    public void setIniciadaEn(Long iniciadaEn) { this.iniciadaEn = iniciadaEn; }
    public Long getAnfitrionVistoEn() { return anfitrionVistoEn; }
    public void setAnfitrionVistoEn(Long anfitrionVistoEn) { this.anfitrionVistoEn = anfitrionVistoEn; }
    public List<String> getLobbyCategorias() { return lobbyCategorias; }
    public void setLobbyCategorias(List<String> lobbyCategorias) { this.lobbyCategorias = lobbyCategorias; }
    public Integer getLobbyMaxRondas() { return lobbyMaxRondas; }
    public void setLobbyMaxRondas(Integer lobbyMaxRondas) { this.lobbyMaxRondas = lobbyMaxRondas; }
    public List<String> getLobbyOpcionesResumen() { return lobbyOpcionesResumen; }
    public void setLobbyOpcionesResumen(List<String> lobbyOpcionesResumen) {
        this.lobbyOpcionesResumen = lobbyOpcionesResumen;
    }
    public int getApuestaMonedas() { return apuestaMonedas; }
    public void setApuestaMonedas(int apuestaMonedas) { this.apuestaMonedas = apuestaMonedas; }
    public boolean isPublica() { return publica; }
    public void setPublica(boolean publica) { this.publica = publica; }
    public Map<String, Object> getGameState() { return gameState; }
    public void setGameState(Map<String, Object> gameState) { this.gameState = gameState; }
}
