package com.juegosmesa.sala.web;

import com.juegosmesa.sala.service.SalaService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.LinkedHashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/sala")
public class SalaController {

    private final SalaService salaService;

    public SalaController(SalaService salaService) {
        this.salaService = salaService;
    }

    @GetMapping
    public ResponseEntity<Map<String, Object>> obtener(@RequestParam(required = false) String codigo) {
        return ResponseEntity.ok(salaService.obtener(codigo));
    }

    @PostMapping
    public ResponseEntity<Map<String, Object>> post(@RequestBody Map<String, Object> body) {
        return ResponseEntity.ok(salaService.post(body));
    }

    @ExceptionHandler(ApiException.class)
    public ResponseEntity<Map<String, Object>> onApiException(ApiException ex) {
        var body = new LinkedHashMap<String, Object>();
        body.put("error", ex.getMessage());
        return ResponseEntity.status(ex.getStatus()).body(body);
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, Object>> onError(Exception ex) {
        var body = new LinkedHashMap<String, Object>();
        body.put("error", ex.getMessage() != null ? ex.getMessage() : "Error del servidor.");
        return ResponseEntity.internalServerError().body(body);
    }
}
