package com.juegosmesa.sala.repository;

import com.juegosmesa.sala.model.SalaDocument;
import org.springframework.data.mongodb.repository.MongoRepository;

import java.util.List;

public interface SalaRepository extends MongoRepository<SalaDocument, String> {
    List<SalaDocument> findByEstado(String estado);
}
