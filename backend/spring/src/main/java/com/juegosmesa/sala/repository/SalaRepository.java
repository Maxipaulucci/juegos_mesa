package com.juegosmesa.sala.repository;

import com.juegosmesa.sala.model.SalaDocument;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface SalaRepository extends MongoRepository<SalaDocument, String> {
}
