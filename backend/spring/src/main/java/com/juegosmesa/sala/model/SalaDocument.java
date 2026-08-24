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
    private List<String> lobbyCategorias = new ArrayList<>();
    private Integer lobbyMaxRondas;
    private Map<String, Object> gameState;

    public Map<String, Object> toMap() {
        var map = new LinkedHashMap<String, Object>();
        map.put("codigo", codigo);
        map.put("juegoId", juegoId);
        map.put("anfitrionId", anfitrionId);
        map.put("jugadores", jugadores.stream().map(JugadorEmbedded::toMap).toList());
        map.put("estado", estado);
        map.put("dados", dados);
        if (creadaEn != null) map.put("creadaEn", creadaEn);
        if (iniciadaEn != null) map.put("iniciadaEn", iniciadaEn);
        map.put("lobbyCategorias", lobbyCategorias != null ? lobbyCategorias : List.of());
        if (lobbyMaxRondas != null) map.put("lobbyMaxRondas", lobbyMaxRondas);
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
    public List<String> getLobbyCategorias() { return lobbyCategorias; }
    public void setLobbyCategorias(List<String> lobbyCategorias) { this.lobbyCategorias = lobbyCategorias; }
    public Integer getLobbyMaxRondas() { return lobbyMaxRondas; }
    public void setLobbyMaxRondas(Integer lobbyMaxRondas) { this.lobbyMaxRondas = lobbyMaxRondas; }
    public Map<String, Object> getGameState() { return gameState; }
    public void setGameState(Map<String, Object> gameState) { this.gameState = gameState; }
}
