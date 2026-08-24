package com.juegosmesa.sala.model;

import java.util.LinkedHashMap;
import java.util.Map;

public class JugadorEmbedded {

    private String id;
    private String nombre;
    private String rol;

    public JugadorEmbedded() {}

    public JugadorEmbedded(String id, String nombre, String rol) {
        this.id = id;
        this.nombre = nombre;
        this.rol = rol;
    }

    public Map<String, Object> toMap() {
        var map = new LinkedHashMap<String, Object>();
        map.put("id", id);
        map.put("nombre", nombre);
        map.put("rol", rol);
        return map;
    }

    public String getId() { return id; }
    public void setId(String id) { this.id = id; }
    public String getNombre() { return nombre; }
    public void setNombre(String nombre) { this.nombre = nombre; }
    public String getRol() { return rol; }
    public void setRol(String rol) { this.rol = rol; }
}
